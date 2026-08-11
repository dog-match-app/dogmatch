# DogMatch — Arquitetura

> "Tinder para cachorros": donos criam perfis para seus cães, descobrem cães próximos,
> dão like/pass e, quando o like é mútuo, vira **match** com chat em tempo real —
> para cruzamento (breeding) ou amizade entre pets.

Este documento é a **fonte da verdade** da arquitetura: contrato da API, modelo de dados,
decisões técnicas e estrutura dos dois apps.

---

## 1. Visão geral

```mermaid
flowchart LR
    subgraph Mobile["📱 Mobile (Flutter)"]
        UI[UI · BLoC] --> Repo[Repositories]
        Repo --> Dio[Dio REST client]
        Repo --> Sock[Socket.IO client]
    end

    subgraph Backend["🖥️ API (NestJS)"]
        REST[REST /api/v1] --> Services
        WS[WS Gateway /chat] --> Services
        Services --> Prisma[Prisma ORM]
        Services --> Queue[BullMQ]
        Services --> S3[S3 presigned URLs]
    end

    Dio --> REST
    Sock --> WS
    Prisma --> PG[(PostgreSQL + PostGIS)]
    Queue --> RD[(Redis)]
    WS --> RD
    S3 --> MINIO[(MinIO / S3)]
    Mobile -- "upload direto via presigned PUT" --> MINIO
```

| Camada | Tecnologia | Papel |
|---|---|---|
| Mobile | Flutter (canal **stable**) | App Android/iOS |
| State management | flutter_bloc + get_it/injectable | Padrão comercial consolidado |
| Backend | NestJS 11 (Node 24 LTS) | API REST versionada + WebSocket |
| ORM | Prisma | Migrations, client tipado |
| Banco | PostgreSQL 16 + **PostGIS** | Dados + busca geoespacial |
| Cache/filas/WS | Redis 7 | BullMQ, adapter Socket.IO |
| Storage | MinIO (dev) / S3 (prod) | Fotos via presigned URL |
| Infra dev | Docker Compose | db, redis, minio, api |

### Decisões (e alternativas consideradas)

1. **flutter_bloc** em vez de Riverpod — ambos são padrão de mercado; BLoC é o mais
   consolidado em times comerciais/enterprise, com camadas bem definidas e `bloc_test`.
2. **Prisma** em vez de TypeORM — ORM TypeScript mais adotado comercialmente hoje;
   migrations declarativas e client 100% tipado. Consultas geoespaciais usam
   `$queryRaw` com PostGIS (padrão comum).
3. **JWT access + refresh com rotação** (refresh persistido com hash, revogável) —
   padrão para mobile; sessões multi-dispositivo na tabela `refresh_tokens`.
4. **Upload direto ao storage via presigned URL** — o app faz `PUT` direto no
   MinIO/S3; a API nunca proxeia bytes de imagem (padrão da indústria p/ mobile).
5. **Socket.IO** para chat — gateway nativo do NestJS + `socket_io_client` no Flutter;
   Redis adapter deixa o WS horizontalmente escalável.
6. **Swipe é por cachorro, não por usuário**: um dono pode ter N cães; ele escolhe com
   qual cão está "jogando". Match é entre dois cães; o chat é entre os dois donos.

---

## 2. Monorepo

```
dogmatch/
├── ARCHITECTURE.md          ← este arquivo
├── README.md                ← quickstart
├── docker-compose.yml       ← db (postgis), redis, minio, api
├── Makefile                 ← atalhos de dev
├── .github/workflows/       ← CI (backend e mobile)
├── backend/                 ← API NestJS
└── mobile/                  ← app Flutter
```

---

## 3. Backend (NestJS)

### 3.1 Estrutura de módulos

```
backend/src/
├── main.ts                  # helmet, CORS, prefix api + versão v1, ValidationPipe,
│                            # Swagger /api/docs, pino logger, Redis WS adapter
├── app.module.ts
├── config/                  # @nestjs/config + validação Joi das envs
├── prisma/                  # PrismaModule global + PrismaService
├── common/
│   ├── decorators/          # @CurrentUser(), @Public()
│   ├── guards/              # JwtAuthGuard global (APP_GUARD, respeita @Public)
│   └── filters/             # PrismaClientExceptionFilter (P2002→409, P2025→404)
└── modules/
    ├── auth/                # register/login/refresh/logout, strategies JWT
    ├── users/               # GET/PATCH /users/me
    ├── files/               # presigned upload URLs (S3/MinIO)
    ├── dogs/                # CRUD de cães + fotos
    ├── discovery/           # feed de cards (PostGIS)
    ├── swipes/              # like/pass + criação de match (transação)
    ├── matches/             # matches + mensagens (REST)
    ├── chat/                # Socket.IO gateway /chat
    ├── notifications/       # BullMQ (placeholder p/ FCM)
    └── health/              # Terminus: GET /health (db + memória)
```

### 3.2 Convenções transversais

- Prefixo global `api` + versionamento URI (`/api/v1/...`). `GET /health` fica **fora** do prefixo.
- `ValidationPipe` global: `whitelist: true, transform: true, forbidNonWhitelisted: true`.
- Autenticação global via `APP_GUARD` (JWT Bearer); rotas públicas anotadas com `@Public()`.
- Senhas e refresh tokens com hash **argon2** (recomendação OWASP).
- Rate limit: `@nestjs/throttler` global (100 req/min) e mais rígido em `/auth/*` (10/min).
- Logs estruturados com `nestjs-pino` (pretty no dev).
- Swagger em `/api/docs` com bearer auth.
- Erros: formato padrão Nest `{ statusCode, message, error }`.

### 3.3 Autenticação

- **Access token**: JWT (`JWT_ACCESS_SECRET`, TTL 15m), payload `{ sub: userId, email }`.
- **Refresh token**: JWT (`JWT_REFRESH_SECRET`, TTL 30d), payload `{ sub, jti }`, onde
  `jti` = id da linha em `refresh_tokens`; a linha guarda `token_hash` (argon2 do token).
- **Rotação**: a cada `/auth/refresh`, o token antigo é revogado (`revoked_at`) e um novo
  par é emitido. Reuso de token revogado ⇒ 401.
- **Logout**: revoga o refresh token enviado.

### 3.4 Upload de fotos

1. App chama `POST /api/v1/files/presigned-upload` `{ contentType, folder, contentLength }`
   (`avatars` | `dogs`).
2. API valida contentType (`image/jpeg|png|webp`) e **contentLength** (1 byte a
   **20 MB** — acima disso 400), gera key `folder/uuid.ext` e assina PUT (300s).
3. App faz `PUT` do binário direto na URL assinada, com `Content-Length` **igual ao
   declarado** — o header entra na assinatura, então o storage rejeita (403) qualquer
   corpo de tamanho diferente. É isso que impede upload maior que o teto mesmo que
   alguém monte a requisição fora do app.
4. App registra a foto (`POST /dogs/:id/photos { key }` ou `PATCH /users/me { avatarUrl }`).
5. Bucket `dogmatch-media` tem leitura pública (download) — URLs finais `S3_PUBLIC_URL/key`.

### 3.5 Geolocalização (discovery)

- Localização fica no **dono** (`users.latitude/longitude`), atualizada pelo app.
- Query raw com PostGIS (índice GIST funcional). Filtros do feed para o cão `X` (dono `U`):
  - cães `active`, de outros donos, com dono geolocalizado;
  - sem **LIKE** de `X`, e sem **PASS** de `X` nos últimos **7 dias** — pass é um
    bloqueio temporário do feed (o cão reaparece depois do período); like é
    definitivo no feed;
  - dentro de `radiusKm` (padrão 50) de `U`, ordenados por distância;
  - **compatibilidade de intenção**:
    - `X.intent = BREEDING` → alvo `intent ∈ {BREEDING, BOTH}` **e** sexo oposto **e** não castrado;
    - `X.intent = FRIENDSHIP` → alvo `intent ∈ {FRIENDSHIP, BOTH}`;
    - `X.intent = BOTH` → união dos dois casos acima.

SQL de referência (parâmetros via `$queryRaw`):

```sql
SELECT d.id, ST_Distance(
         ST_SetSRID(ST_MakePoint(u.longitude, u.latitude), 4326)::geography,
         ST_SetSRID(ST_MakePoint($lng, $lat), 4326)::geography
       ) AS distance_m
FROM dogs d
JOIN users u ON u.id = d.owner_id
WHERE d.active = true
  AND d.owner_id <> $meId
  AND u.latitude IS NOT NULL AND u.longitude IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM swipes s
                  WHERE s.swiper_dog_id = $dogId AND s.target_dog_id = d.id)
  AND ST_DWithin(
        ST_SetSRID(ST_MakePoint(u.longitude, u.latitude), 4326)::geography,
        ST_SetSRID(ST_MakePoint($lng, $lat), 4326)::geography,
        $radiusM)
  AND ( /* cláusula de compatibilidade de intent conforme acima */ )
ORDER BY distance_m ASC
LIMIT $limit;
```

### 3.5.1 Busca com filtros (estilo OLX)

Complemento ao swipe: `GET /discovery/search` lista cães com filtros explícitos e
paginação — exploração ativa, sem a mecânica de deck. Regras:

| Param | Tipo | Semântica |
|---|---|---|
| `q` | string | busca textual em `name` + `breed` (`ILIKE %q%`) |
| `sex` | `MALE\|FEMALE` | sexo exato |
| `size` | CSV (`SMALL,MEDIUM,...`) | um ou mais portes |
| `intent` | `BREEDING\|FRIENDSHIP` | disponibilidade: `BREEDING` ⇒ alvo `IN (BREEDING, BOTH)`; `FRIENDSHIP` ⇒ alvo `IN (FRIENDSHIP, BOTH)` (sem lógica automática de sexo oposto — busca é filtro explícito) |
| `ageMinYears` / `ageMaxYears` | int ≥ 0 | faixa etária via `birthDate` |
| `neutered` / `pedigree` | bool | quando presentes, filtram exato |
| `radiusKm` | int 1..500 | distância a partir da localização **do usuário logado** (400 `LOCATION_REQUIRED` se ele não tiver lat/lng) |
| `dogId` | uuid | perspectiva do cão ativo (precisa ser do usuário — 403): habilita `myAction`/`matched` nos cards e o `excludeSwiped` |
| `excludeSwiped` | bool (default false) | oculta cães já swipados pelo `dogId` (400 se sem `dogId`) |
| `orderBy` | `distance\|recent` | default: `distance` se o usuário tem localização, senão `recent` (`createdAt desc`). `distance` sem localização ⇒ 400 `LOCATION_REQUIRED` |
| `page` / `limit` | int (default 1 / 20, máx 50) | paginação offset com `total`/`pageCount` |

Ao contrário do feed de swipe, a busca **inclui os cães do próprio usuário**,
marcados com `isMine: true` (o app destaca no card e não oferece curtir/passar).
Sempre excluídos: cães inativos. `distanceKm` vem `null` quando
uma das partes não tem localização. Implementação: mesma abordagem do feed —
`$queryRaw` com cláusulas `Prisma.sql` compostas (count + página) e enriquecimento
(fotos, swipe/match da perspectiva) via Prisma preservando a ordem.

### 3.5.2 Página do cão (posts)

Cada cão tem uma página personalizada montada pelo dono com **até 10 posts**
(400 `POST_LIMIT_REACHED` ao exceder). Tipos e validações:

| Tipo | Regras |
|---|---|
| `TEXT` | `text` 1..2000 chars, sem imagens |
| `IMAGE` | exatamente 1 imagem, sem `text` |
| `IMAGE_TEXT` | exatamente 1 imagem + `text` 1..2000 |
| `CAROUSEL` | 2..8 imagens, `text` opcional (≤2000) |

- Imagens pelo fluxo presigned normal (folder `dogs`); o post referencia a `key`.
- **Legendas posicionadas**: cada imagem aceita 0..5 legendas `{ text (1..200), x, y }`
  com `x`/`y` ∈ [0,1] (fração da largura/altura — âncora do marcador na imagem).
- `text` armazena formatação leve estilo Telegram, renderizada no app:
  `**negrito**`, `__itálico__`, `~~riscado~~`, `` `mono` ``. O servidor guarda cru
  (sem sanitização de markup; tamanho validado).
- Mutações só do dono (403). Leitura: qualquer autenticado. Ordem: `createdAt desc`.
- `PATCH` substitui o conteúdo (text/imagens/legendas) em transação; `type` é imutável.

### 3.5.3 Redes sociais do cão

Campos opcionais no cadastro do cão (o dono decide se aponta para a rede do cão ou
a dele): `whatsapp`, `instagram`, `pinterest`, `telegram` (strings livres ≤100 —
handle, número ou URL; o app monta o deep link: `wa.me/<dígitos>`,
`instagram.com/<handle>`, `pinterest.com/<handle>`, `t.me/<handle>`; valores
`http(s)://` são usados como estão). Exibidos no detalhe como botões com as cores
oficiais das marcas.

### 3.6 Swipe → Match

`POST /swipes` roda em **transação**:
1. Valida que `swiperDogId` pertence ao usuário e `targetDogId` existe/ativo/não é dele.
2. Upsert do swipe (`@@unique(swiperDogId, targetDogId)`). **Re-swipe atualiza**
   `action` e `createdAt` — em particular `PASS → LIKE` é permitido (desfazer um
   pass acidental curtindo depois, ex.: pela busca/detalhe) e refaz a checagem de
   match; repetir a mesma ação apenas renova `createdAt` (no PASS, isso reinicia a
   janela de 7 dias do feed).
3. Se a ação final é `LIKE` e existe like reverso → cria `Match` com `dogAId < dogBId`
   (ordenação canônica evita duplicatas) e emite `match.created` (EventEmitter2).
4. Resposta: `{ matched: boolean, match?: MatchDto }`.

`match.created` é consumido por: **ChatGateway** (emite `match:new` aos dois donos) e
**NotificationsListener** (enfileira job BullMQ — placeholder de push FCM).

### 3.7 WebSocket — namespace `/chat`

Handshake: `auth: { token: <accessToken> }` (verificação JWT; conexão recusada se inválido).
Ao conectar, o socket entra no room `user:<userId>`.

| Direção | Evento | Payload |
|---|---|---|
| C → S | `match:join` | `{ matchId }` (valida membership; entra no room `match:<id>`) |
| C → S | `message:send` | `{ matchId, content }` (persiste e faz broadcast) |
| C → S | `typing` | `{ matchId }` |
| S → C | `message:new` | `MessageDto` (room do match + room do outro dono) |
| S → C | `typing` | `{ matchId, userId }` |
| S → C | `match:new` | `MatchDto` (para os dois donos) |

---

## 4. Contrato da API v1 (fonte da verdade)

Base: `http://localhost:3000/api/v1` · Auth: `Authorization: Bearer <accessToken>` ·
Datas em ISO-8601 UTC. Campos em camelCase.

### DTOs

```ts
UserDto        { id, email, name, phone?, bio?, avatarUrl?, city?,
                 latitude?, longitude?, createdAt }
DogDto         { id, ownerId, name, breed, sex: 'MALE'|'FEMALE',
                 birthDate, size: 'SMALL'|'MEDIUM'|'LARGE'|'GIANT',
                 intent: 'BREEDING'|'FRIENDSHIP'|'BOTH', bio?,
                 neutered, pedigree, active,
                 photos: [{ id, url, position }],
                 social: { whatsapp?, instagram?, pinterest?, telegram? }, createdAt }
DogPostCaptionDto { id, text, x, y }          // x/y ∈ [0,1]
DogPostImageDto { id, url, position, captions: DogPostCaptionDto[] }
DogPostDto     { id, dogId, type: 'TEXT'|'IMAGE'|'IMAGE_TEXT'|'CAROUSEL',
                 text?, images: DogPostImageDto[], createdAt, updatedAt }
AuthResponseDto { user: UserDto, accessToken, refreshToken }
TokensDto      { accessToken, refreshToken }
DiscoveryCardDto { dog: DogDto, distanceKm: number,
                   owner: { id, name, city?, avatarUrl? } }
SearchCardDto  { dog: DogDto, distanceKm?: number|null,
                 owner: { id, name, city?, avatarUrl? },
                 myAction?: 'LIKE'|'PASS'|null, matched?: boolean,
                 isMine: boolean }   // cão do próprio usuário
SearchResultDto { items: SearchCardDto[], total, page, pageCount }
SwipeResultDto { matched: boolean, match?: MatchDto }
MatchDto       { id, createdAt, myDog: DogDto, otherDog: DogDto,
                 otherOwner: { id, name, avatarUrl? }, lastMessage?: MessageDto,
                 unreadCount: number }   // mensagens do outro sem readAt
LikeReceivedDto  { dog: DogDto, distanceKm?: number|null,
                   owner: { id, name, city?, avatarUrl? },
                   likedAt, myAction: 'PASS'|null }
LikesReceivedDto { items: LikeReceivedDto[], total }
MessageDto     { id, matchId, senderId, content, createdAt, readAt? }
PresignedUploadDto { uploadUrl, publicUrl, key, expiresIn }
OwnerProfileDto { id, name, bio?, avatarUrl?, city?, memberSince,
                  distanceKm?: number|null,
                  stats: { dogs: number, matches: number },
                  dogs: DogDto[] }   // perfil público: NUNCA expõe email,
                                     // telefone ou coordenadas
```

### Endpoints

| Método | Rota | Auth | Body / Query | Resposta |
|---|---|---|---|---|
| POST | `/auth/register` | ✖ | `{ email, password (≥8), name }` | 201 `AuthResponseDto` |
| POST | `/auth/login` | ✖ | `{ email, password }` | 200 `AuthResponseDto` |
| POST | `/auth/refresh` | ✖ | `{ refreshToken }` | 200 `TokensDto` (rotação) |
| POST | `/auth/logout` | ✔ | `{ refreshToken }` | 204 |
| GET | `/users/me` | ✔ | — | `UserDto` (inclui `dogs`) |
| PATCH | `/users/me` | ✔ | `{ name?, bio?, phone?, city?, latitude?, longitude?, avatarUrl? }` | `UserDto` |
| GET | `/users/:id/profile` | ✔ | — | `OwnerProfileDto` (cães ativos; `distanceKm` se ambos têm localização; `stats.matches` = matches dos cães do dono) |
| POST | `/files/presigned-upload` | ✔ | `{ contentType, folder: 'avatars'\|'dogs', contentLength: 1..20971520 }` | `PresignedUploadDto` |
| GET | `/dogs/mine` | ✔ | — | `DogDto[]` |
| POST | `/dogs` | ✔ | `{ name, breed, sex, birthDate, size, intent, bio?, neutered?, pedigree?, whatsapp?, instagram?, pinterest?, telegram? }` | 201 `DogDto` |
| GET | `/dogs/:id` | ✔ | — | `DogDto` + `owner: { id, name, city?, avatarUrl? }` |
| PATCH | `/dogs/:id` | ✔ (dono) | campos parciais | `DogDto` |
| DELETE | `/dogs/:id` | ✔ (dono) | — | 204 |
| POST | `/dogs/:id/photos` | ✔ (dono) | `{ key, position? }` (máx. 6 fotos) | 201 photo |
| DELETE | `/dogs/:id/photos/:photoId` | ✔ (dono) | — | 204 |
| GET | `/dogs/:id/posts` | ✔ | — | `DogPostDto[]` (createdAt desc) |
| POST | `/dogs/:id/posts` | ✔ (dono) | `{ type, text?, images?: [{ key, position?, captions?: [{text,x,y}] }] }` (§3.5.2) | 201 `DogPostDto` |
| PATCH | `/dogs/:id/posts/:postId` | ✔ (dono) | mesmo shape sem `type` (conteúdo substituído) | `DogPostDto` |
| DELETE | `/dogs/:id/posts/:postId` | ✔ (dono) | — | 204 |
| GET | `/discovery` | ✔ | `?dogId=&radiusKm=50&limit=20` | `DiscoveryCardDto[]` |
| GET | `/discovery/search` | ✔ | filtros do §3.5.1 | `SearchResultDto` |
| POST | `/swipes` | ✔ | `{ swiperDogId, targetDogId, action: 'LIKE'\|'PASS' }` | `SwipeResultDto` |
| GET | `/swipes/received` | ✔ (dono) | `?dogId=` opcional — likes recebidos **sem** like recíproco e **sem** match; inclui os que você passou (`myAction: 'PASS'`, reversível); ordem `likedAt desc`; **sem `dogId`, agrega todos os cães ativos do usuário** (uso do badge) | `LikesReceivedDto` |
| POST | `/matches/:id/read` | ✔ (participante) | — marca como lidas as mensagens do outro | 204 |
| GET | `/matches` | ✔ | `?dogId=` | `MatchDto[]` |
| GET | `/matches/:id/messages` | ✔ | `?cursor=&limit=30` | `{ items: MessageDto[], nextCursor? }` |
| POST | `/matches/:id/messages` | ✔ | `{ content }` | 201 `MessageDto` |
| GET | `/health` (sem prefixo) | ✖ | — | Terminus |

Erros relevantes: `409` email duplicado; `401` credenciais/refresh inválidos; `403` recurso
de outro usuário; `400 LOCATION_REQUIRED` discovery sem localização no perfil;
`400 NEUTERED_BREEDING_INCOMPATIBLE` ao criar/editar cão castrado com intenção
só-cruzamento (perfil seria invisível em qualquer deck — ver §3.5).

---

## 5. Modelo de dados (Prisma)

```prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

enum DogSex {
  MALE
  FEMALE
}

enum DogSize {
  SMALL
  MEDIUM
  LARGE
  GIANT
}

enum DogIntent {
  BREEDING
  FRIENDSHIP
  BOTH
}

enum SwipeAction {
  LIKE
  PASS
}

model User {
  id           String   @id @default(uuid()) @db.Uuid
  email        String   @unique
  passwordHash String   @map("password_hash")
  name         String
  phone        String?
  bio          String?
  avatarUrl    String?  @map("avatar_url")
  city         String?
  latitude     Float?
  longitude    Float?
  createdAt    DateTime @default(now()) @map("created_at")
  updatedAt    DateTime @updatedAt @map("updated_at")

  dogs          Dog[]
  refreshTokens RefreshToken[]
  messages      Message[]

  @@map("users")
}

model RefreshToken {
  id        String    @id @default(uuid()) @db.Uuid
  userId    String    @map("user_id") @db.Uuid
  tokenHash String    @map("token_hash")
  userAgent String?   @map("user_agent")
  expiresAt DateTime  @map("expires_at")
  revokedAt DateTime? @map("revoked_at")
  createdAt DateTime  @default(now()) @map("created_at")

  user User @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@index([userId])
  @@map("refresh_tokens")
}

enum DogPostType {
  TEXT
  IMAGE
  IMAGE_TEXT
  CAROUSEL
}

model Dog {
  id        String    @id @default(uuid()) @db.Uuid
  ownerId   String    @map("owner_id") @db.Uuid
  name      String
  breed     String
  sex       DogSex
  birthDate DateTime  @map("birth_date")
  size      DogSize
  intent    DogIntent
  bio       String?
  neutered  Boolean   @default(false)
  pedigree  Boolean   @default(false)
  active    Boolean   @default(true)
  socialWhatsapp  String? @map("social_whatsapp")
  socialInstagram String? @map("social_instagram")
  socialPinterest String? @map("social_pinterest")
  socialTelegram  String? @map("social_telegram")
  createdAt DateTime  @default(now()) @map("created_at")
  updatedAt DateTime  @updatedAt @map("updated_at")

  owner          User       @relation(fields: [ownerId], references: [id], onDelete: Cascade)
  photos         DogPhoto[]
  posts          DogPost[]
  swipesGiven    Swipe[]    @relation("DogSwipesGiven")
  swipesReceived Swipe[]    @relation("DogSwipesReceived")
  matchesAsA     Match[]    @relation("MatchDogA")
  matchesAsB     Match[]    @relation("MatchDogB")

  @@index([ownerId])
  @@map("dogs")
}

model DogPhoto {
  id        String   @id @default(uuid()) @db.Uuid
  dogId     String   @map("dog_id") @db.Uuid
  key       String
  url       String
  position  Int      @default(0)
  createdAt DateTime @default(now()) @map("created_at")

  dog Dog @relation(fields: [dogId], references: [id], onDelete: Cascade)

  @@index([dogId])
  @@map("dog_photos")
}

model DogPost {
  id        String      @id @default(uuid()) @db.Uuid
  dogId     String      @map("dog_id") @db.Uuid
  type      DogPostType
  text      String?
  createdAt DateTime    @default(now()) @map("created_at")
  updatedAt DateTime    @updatedAt @map("updated_at")

  dog    Dog            @relation(fields: [dogId], references: [id], onDelete: Cascade)
  images DogPostImage[]

  @@index([dogId, createdAt])
  @@map("dog_posts")
}

model DogPostImage {
  id       String @id @default(uuid()) @db.Uuid
  postId   String @map("post_id") @db.Uuid
  key      String
  url      String
  position Int    @default(0)

  post     DogPost               @relation(fields: [postId], references: [id], onDelete: Cascade)
  captions DogPostImageCaption[]

  @@index([postId])
  @@map("dog_post_images")
}

model DogPostImageCaption {
  id      String @id @default(uuid()) @db.Uuid
  imageId String @map("image_id") @db.Uuid
  text    String
  x       Float
  y       Float

  image DogPostImage @relation(fields: [imageId], references: [id], onDelete: Cascade)

  @@index([imageId])
  @@map("dog_post_image_captions")
}

model Swipe {
  id          String      @id @default(uuid()) @db.Uuid
  swiperDogId String      @map("swiper_dog_id") @db.Uuid
  targetDogId String      @map("target_dog_id") @db.Uuid
  action      SwipeAction
  createdAt   DateTime    @default(now()) @map("created_at")

  swiperDog Dog @relation("DogSwipesGiven", fields: [swiperDogId], references: [id], onDelete: Cascade)
  targetDog Dog @relation("DogSwipesReceived", fields: [targetDogId], references: [id], onDelete: Cascade)

  @@unique([swiperDogId, targetDogId])
  @@index([targetDogId])
  @@map("swipes")
}

model Match {
  id        String   @id @default(uuid()) @db.Uuid
  dogAId    String   @map("dog_a_id") @db.Uuid
  dogBId    String   @map("dog_b_id") @db.Uuid
  createdAt DateTime @default(now()) @map("created_at")

  dogA     Dog       @relation("MatchDogA", fields: [dogAId], references: [id], onDelete: Cascade)
  dogB     Dog       @relation("MatchDogB", fields: [dogBId], references: [id], onDelete: Cascade)
  messages Message[]

  @@unique([dogAId, dogBId])
  @@map("matches")
}

model Message {
  id        String    @id @default(uuid()) @db.Uuid
  matchId   String    @map("match_id") @db.Uuid
  senderId  String    @map("sender_id") @db.Uuid
  content   String
  createdAt DateTime  @default(now()) @map("created_at")
  readAt    DateTime? @map("read_at")

  match  Match @relation(fields: [matchId], references: [id], onDelete: Cascade)
  sender User  @relation(fields: [senderId], references: [id], onDelete: Cascade)

  @@index([matchId, createdAt])
  @@map("messages")
}
```

**Migração adicional (PostGIS)** — anexar ao SQL da migration inicial:

```sql
CREATE EXTENSION IF NOT EXISTS postgis;

CREATE INDEX IF NOT EXISTS users_location_gix
  ON users
  USING GIST ((ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography))
  WHERE longitude IS NOT NULL AND latitude IS NOT NULL;
```

Invariante de aplicação: em `matches`, sempre `dogAId < dogBId` (ordenação lexicográfica
dos UUIDs) para a unique constraint impedir pares duplicados.

---

## 6. Mobile (Flutter)

### 6.1 Arquitetura

Clean architecture **feature-first** com 3 camadas por feature (pragmática, sem camada de
use cases — repositório → cubit/bloc direto):

```
mobile/lib/
├── main.dart                     # bootstrap + DI + runApp
├── app/
│   ├── app.dart                  # MaterialApp.router, tema, locale pt_BR
│   ├── router/app_router.dart    # go_router + guards por estado de auth
│   ├── theme/app_theme.dart      # Material 3, seed laranja
│   └── di/injection.dart         # get_it + injectable
├── core/
│   ├── config/app_config.dart    # API_BASE_URL via --dart-define
│   ├── network/                  # Dio + AuthInterceptor (refresh c/ fila) + SocketClient
│   ├── storage/token_storage.dart# flutter_secure_storage
│   ├── error/                    # ApiException, failure mapping
│   └── widgets/                  # botões, loading, empty state
└── features/
    ├── auth/        # AuthBloc global + Login/Register (cubits + pages)
    ├── profile/     # perfil do dono, localização (geolocator), avatar
    ├── dogs/        # meus cães, formulário, fotos, página do cão (posts + editor)
    ├── discovery/   # deck de swipe (flutter_card_swiper), seletor de cão ativo
    ├── search/      # busca com filtros estilo OLX + detalhe do cão
    ├── matches/     # lista de matches
    └── chat/        # conversa (Socket.IO + fallback REST)

features/<x>/
├── data/       # models (json_serializable), api datasource, repository impl
├── domain/     # entities (equatable), repository contract
└── presentation/ # bloc|cubit, pages, widgets
```

### 6.2 Pacotes

| Pacote | Uso |
|---|---|
| flutter_bloc, equatable, bloc_test | State management + testes |
| get_it, injectable (+generator) | Injeção de dependência |
| dio | HTTP + interceptors (bearer/refresh) |
| go_router | Navegação declarativa + redirect por auth |
| flutter_secure_storage | Tokens no Keychain/Keystore |
| json_annotation / json_serializable | Serialização dos DTOs |
| socket_io_client | Chat em tempo real |
| flutter_card_swiper | Deck de swipe estilo Tinder |
| image_picker | Fotos (galeria/câmera) |
| geolocator | Localização do dono |
| cached_network_image | Cache das fotos |
| intl + flutter_localizations | pt_BR |
| font_awesome_flutter | Ícones de marca das redes sociais |
| url_launcher | Abrir deep links das redes (wa.me, instagram, t.me…) |

### 6.3 Fluxos-chave

- **Auth**: `AuthBloc` global (`unknown → authenticated | unauthenticated`), splash decide
  a rota; `go_router.redirect` escuta o bloc. `AuthInterceptor` injeta o bearer, e em 401
  pausa a fila de requests, tenta `/auth/refresh`, repete a request; falhou ⇒ logout global.
- **Config**: `API_BASE_URL` via `--dart-define` (default `http://10.0.2.2:3000`, o
  localhost visto pelo emulador Android).
- **Discovery**: usuário escolhe o cão ativo (dropdown) → cubit carrega cards →
  swipe direita = LIKE, esquerda = PASS → `matched: true` abre dialog "Deu match! 🐾".
  Raio máximo de sugestões configurável na própria aba (preferência local do app,
  enviada como `radiusKm`). **Curtir/Passar como par só existe no deck**: o detalhe
  do cão oferece apenas "Curtir" (sempre habilitado se não houver match), para que
  um pass acidental possa ser revertido pela busca; a busca indica visualmente o
  pass (`myAction = PASS`).
- **Busca (OLX-like)**: aba própria com campo de busca (debounce), bottom sheet de
  filtros (sexo, porte, intenção, idade, raio, ordenação), lista paginada com scroll
  infinito → detalhe do cão (carousel de fotos, infos, dono) com ações Curtir/Passar
  usando o cão ativo; badges de "já curtido"/"match" nos cards.
- **Página do cão**: detalhe com abas "Perfil" | "Posts". Posts renderizados por tipo
  (texto formatado estilo Telegram via parser próprio, imagem → viewer, carrossel com
  marcadores de legenda posicionados tocáveis). Dono edita em "Página do cão" (meus
  cães): composer por tipo com botão de ajuda da formatação, contador X/10, legendas
  criadas tocando no ponto da imagem. Botões de redes sociais no detalhe com as cores
  das marcas (constantes em `social_brand.dart` — exceção documentada ao tema).
- **Upload**: image_picker → `POST /files/presigned-upload` → `PUT` binário → registra key.
- **Chat**: conecta no namespace `/chat` com o access token, `match:join`, envia por
  socket (fallback REST se desconectado), recebe `message:new`.
- **Curtidas e avisos**: a aba Matches tem segmentos "Matches" | "Curtidas" (likes
  recebidos, com "Curtir de volta"). Badges: contagem de não lidas por match
  (`unreadCount`), novos matches/curtidas desde a última visita (lastSeen local).
  Notificações do SO via `flutter_local_notifications` disparadas pelos eventos do
  socket (`match:new`, `message:new`) com o app aberto/minimizado; push com o app
  fechado exige FCM (roadmap §9 — depende de projeto Firebase).

---

## 7. Infra

### 7.1 Dev (docker-compose)

| Serviço | Imagem | Porta | Observação |
|---|---|---|---|
| db | postgis/postgis:16-3.4 | 5432 | volume persistente, healthcheck |
| redis | redis:7-alpine | 6379 | BullMQ + WS adapter |
| minio | minio/minio | 9000/9001 | console web em :9001 |
| minio-setup | minio/mc | — | cria bucket `dogmatch-media` (download público) |
| api | build backend/ | 3000 | perfil `api` (opcional; dev roda `npm run start:dev`) |

> **Emulador Android**: `localhost` da máquina = `10.0.2.2` no emulador. Para upload de
> fotos funcionar no emulador, use `S3_ENDPOINT=http://10.0.2.2:9000` e
> `S3_PUBLIC_URL=http://10.0.2.2:9000/dogmatch-media` no `backend/.env` (a assinatura
> presigned embute o host). iOS simulator usa `localhost` normalmente. **Celular
> físico**: mesmo raciocínio com o IP da máquina na rede Wi-Fi — guia completo em
> `mobile/README.md` ("Rodando no seu celular").

### 7.2 Variáveis de ambiente (backend/.env)

```env
NODE_ENV=development
PORT=3000
DATABASE_URL="postgresql://dogmatch:dogmatch@localhost:5432/dogmatch?schema=public"
JWT_ACCESS_SECRET=dev-access-secret-change-me
JWT_ACCESS_TTL=15m
JWT_REFRESH_SECRET=dev-refresh-secret-change-me
JWT_REFRESH_TTL=30d
REDIS_URL=redis://localhost:6379
S3_ENDPOINT=http://localhost:9000
S3_REGION=us-east-1
S3_ACCESS_KEY=dogmatch
S3_SECRET_KEY=dogmatch123
S3_BUCKET=dogmatch-media
S3_PUBLIC_URL=http://localhost:9000/dogmatch-media
CORS_ORIGINS=*
THROTTLE_TTL=60000
THROTTLE_LIMIT=100
```

### 7.3 Produção (caminho recomendado)

- **API**: imagem Docker (multi-stage) → Cloud Run / ECS Fargate / Railway / Fly.io.
- **Banco**: Postgres gerenciado com PostGIS (RDS, Cloud SQL, Neon, Supabase).
- **Redis**: ElastiCache / Upstash. **Storage**: S3 + CloudFront (mesmo client AWS SDK).
- Migrations via `prisma migrate deploy` no pipeline. Secrets no secret manager.
- Observabilidade: pino → agregador (Datadog/Grafana Loki), `/health` como probe.

---

## 8. CI (GitHub Actions)

- `backend-ci`: Node 24 → `npm ci`, `prisma generate`, lint, testes, build.
- `mobile-ci`: Flutter stable → `pub get`, `build_runner`, `analyze`, testes.

---

## 9. Roadmap (não incluído no scaffold inicial)

- Push notifications (FCM) — a fila BullMQ `notifications` já é o ponto de integração.
- Read receipts/unread count no chat; paginação do discovery com score de compatibilidade.
- Verificação de pedigree (upload de documento + revisão), denúncia/bloqueio de usuários.
- Moderação de imagens (AWS Rekognition), premium/assinaturas (RevenueCat).
- Testes e2e da API (Testcontainers) e integração no mobile (patrol/integration_test).
- CD: build de imagem + deploy automático; fastlane p/ lojas.
