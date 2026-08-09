# 🐾 DogMatch

**Tinder para cachorros** — donos conectam seus cães para cruzamento ou amizade:
swipe, match e chat em tempo real, com busca por filtros e uma página própria para
cada cão.

| | |
|---|---|
| 📱 Mobile | Flutter (stable) · flutter_bloc · go_router · dio · socket_io_client |
| 🖥️ Backend | NestJS 11 · Prisma · PostgreSQL + PostGIS · Redis · Socket.IO · BullMQ |
| 📦 Infra dev | Docker Compose (Postgres+PostGIS, Redis, MinIO) |

## O que o app faz

- **Descobrir** — deck de swipe com cães próximos (raio geográfico via PostGIS),
  filtrando por compatibilidade de intenção; like mútuo vira **match**.
- **Buscar** — lista estilo classificados com filtros de sexo, porte, intenção,
  faixa etária, distância e ordenação, com paginação e busca por nome/raça.
- **Página do cão** — perfil com fotos (tela cheia com zoom), características
  categorizadas, redes sociais do cão/dono e uma aba de **posts** criados pelo dono
  (texto formatado, imagem, imagem+texto ou carrossel com legendas posicionadas nas
  fotos; até 10 posts por cão).
- **Perfil público do dono** — estatísticas, tempo de casa e todos os cães dele.
- **Chat em tempo real** — conversa por match via WebSocket, com histórico paginado
  e fallback REST quando o socket cai.
- **Conta e perfil** — cadastro/login com refresh token rotativo, avatar, bio e
  localização do dono.

## Documentação

| Documento | Conteúdo |
|---|---|
| **[ARCHITECTURE.md](./ARCHITECTURE.md)** | **Fonte da verdade**: contrato da API v1, schema Prisma, eventos WebSocket, envs e decisões técnicas |
| **[DEPLOY.md](./DEPLOY.md)** | Publicar o backend numa VPS com Coolify (com ou sem domínio), storage (R2/MinIO/Garage), limites de memória |
| **[mobile/README.md](./mobile/README.md)** | Rodar no emulador, **no celular físico** e gerar/instalar APK |
| **[backend/README.md](./backend/README.md)** | Comandos da API, migrations, seed |
| `CLAUDE.md` (raiz, `backend/`, `mobile/`) | Padrões de código e convenções obrigatórias por módulo |

## Pré-requisitos

- Docker + Docker Compose
- Node.js ≥ 22 (recomendado 24 LTS)
- Flutter SDK (canal stable) — em `~/development/flutter`, já no PATH via `~/.bashrc`
- Android SDK — só para emulador/celular; em `~/Android/Sdk` + JDK 21 em
  `~/development/jdk-21` (guia em [mobile/README.md](./mobile/README.md#-rodando-no-seu-celular-android))

## Subindo tudo (dev)

```bash
# 1. Infra (Postgres+PostGIS, Redis, MinIO)
make up

# 2. Backend
cd backend
cp .env.example .env        # já vem pronto para o compose local
npm install
npx prisma migrate dev      # aplica migrations
npx prisma db seed          # dados de demonstração
npm run start:dev           # API em http://localhost:3000

# 3. Mobile (emulador Android)
cd ../mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

- Swagger: http://localhost:3000/api/docs
- Health: http://localhost:3000/health
- Console MinIO: http://localhost:9001 (dogmatch / dogmatch123)
- Prisma Studio: `make studio`

### Usuários de demonstração (seed)

| E-mail | Senha | Conteúdo |
|---|---|---|
| ana@demo.com | `Senha123!` | 2 cães, 1 match com conversa |
| bruno@demo.com | `Senha123!` | 3 cães (o Rex tem posts e redes sociais) |
| carla@demo.com | `Senha123!` | cães variados para testar os filtros |

Os cães ficam em bairros reais de São Paulo — as distâncias na busca e no deck são
calculadas de verdade.

### Rodando no seu celular (Android)

Passo a passo completo (Android SDK, depuração USB, IP/firewall, fotos) em
**[mobile/README.md → "Rodando no seu celular"](./mobile/README.md#-rodando-no-seu-celular-android)**.
Direto pelo cabo:

```bash
flutter run --dart-define=API_BASE_URL=http://SEU_IP_LOCAL:3000   # hostname -I
```

Se o aparelho bloqueia `adb install` (caso de vários Xiaomi/MIUI), gere o APK e
instale manualmente:

```bash
make apk        # detecta seu IP e embute a URL da API no APK
make push-apk   # copia para /sdcard/Download via adb → instale pelo gerenciador de arquivos
```

> As fotos exigem que `S3_ENDPOINT`/`S3_PUBLIC_URL` no `backend/.env` usem o **IP da
> máquina** (não `localhost`): a URL assinada embute o host e o celular precisa
> alcançá-lo. Libere as portas no firewall: `sudo ufw allow 3000/tcp && sudo ufw allow 9000/tcp`.

## Comandos úteis (`make help`)

| Comando | Ação |
|---|---|
| `make up` / `make down` | Sobe/derruba a infra |
| `make nuke` | Derruba **e apaga volumes** (reset total) |
| `make api` | API em modo watch |
| `make migrate` / `make seed` | Prisma migrate / seed |
| `make studio` | Prisma Studio |
| `make apk` / `make push-apk` | Gera o APK release / copia para o celular |
| `make test-backend` / `make lint-backend` | Testes e lint da API |
| `make analyze-mobile` / `make test-mobile` | Análise estática e testes do app |
| `make run-mobile` | Roda o app no emulador |

## Qualidade

Definition of done de qualquer mudança (é o que o CI cobra):

```bash
cd backend && npm run lint && npm test && npm run build
cd mobile && dart run build_runner build && flutter analyze && flutter test
```

`flutter analyze` deve terminar com **zero issues**. Mudanças de contrato (endpoint,
DTO, evento WebSocket, env) começam no `ARCHITECTURE.md` e são refletidas nos dois
lados na mesma tarefa.

## Estrutura

```
├── ARCHITECTURE.md          → contrato da API, schema, decisões (fonte da verdade)
├── DEPLOY.md                → publicar o backend numa VPS (Coolify)
├── backend/                 → API NestJS (REST /api/v1 + WebSocket /chat)
│   ├── prisma/              → schema, migrations e seed
│   └── src/modules/         → auth, users, dogs, discovery, swipes, matches, chat…
├── mobile/                  → App Flutter (Android/iOS)
│   └── lib/features/        → auth, profile, dogs, discovery, search, owners, matches, chat
├── docker-compose.yml       → infra de desenvolvimento
└── Makefile                 → atalhos do dia a dia
```
