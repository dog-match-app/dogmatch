# CLAUDE.md — Backend (API NestJS)

API do DogMatch: NestJS 11 + Prisma 6 + PostgreSQL/PostGIS + Redis + MinIO/S3.
O contrato da API v1, o schema Prisma e os eventos WS estão em `../ARCHITECTURE.md`
(**fonte da verdade** — atualize-o ANTES de mudar o contrato; o app Flutter espelha ele).

## Comandos

```bash
npm run start:dev     # watch mode (exige infra: make up na raiz)
npm run build         # obrigatório verde antes de concluir
npm run lint          # eslint com --fix embutido; obrigatório verde
npm test              # jest unit (roda SEM infra; mocks de Prisma)
npx prisma migrate dev --name <descricao>   # nova migration
npx prisma db seed    # dados demo (idempotente)
npx prisma studio     # inspecionar o banco
```

## Invariantes (nunca violar)

1. **Toda rota é autenticada por padrão** (`JwtAuthGuard` global). Rota pública exige
   `@Public()` explícito. Não criar guards por-controller para JWT.
2. **Validação só por DTO** com class-validator em `dto/` (ValidationPipe global tem
   `whitelist + forbidNonWhitelisted`: campo fora do DTO ⇒ 400). Todo campo de DTO
   leva `@ApiProperty`/`@ApiPropertyOptional` (Swagger é parte do contrato).
3. **Controllers finos**: zero regra de negócio; validam formato (DTO) e delegam ao
   service. Regra de negócio e autorização de recurso (ownership) vivem nos services.
4. **SQL cru apenas com `Prisma.sql` parametrizado** (interpolação de string = injection).
5. **Migrations são imutáveis** depois de aplicadas — mudou o schema, nova migration.
   Banco em snake_case via `@map`/`@@map`; ids `uuid` (`@db.Uuid`); datas UTC.
6. **Senhas e refresh tokens sempre com argon2**; nunca logar tokens/senhas; segredos
   só via env (validadas em `src/config/env.validation.ts` — env nova entra lá + em
   `.env.example` + ARCHITECTURE §7.2 + `docker-compose.yml` quando aplicável).
7. **Side-effects assíncronos via eventos + fila**: request nunca espera efeito
   secundário. Padrão: service emite `EventEmitter2` (`<entidade>.<ação>`, payload
   tipado em `src/common/events/`) → listeners (gateway, fila BullMQ) reagem.
8. Erros: exceções HTTP do Nest com mensagens em inglês. `P2002→409` e `P2025→404`
   já são mapeados pelo `PrismaClientExceptionFilter` global — não capture Prisma
   error code em service para isso.

## Fluxo de uma request

`ThrottlerGuard → JwtAuthGuard (@Public? pula) → Controller (DTO) → Service (negócio
+ ownership) → PrismaService` — respostas montadas explicitamente (nunca vazar
`passwordHash`/`tokenHash`).

## Padrões por módulo (`src/modules/`)

### auth
- Access JWT `{sub, email}` (TTL curto) e refresh JWT `{sub, jti}` onde `jti` = id da
  linha em `refresh_tokens` (hash argon2 do token armazenado). **Rotação obrigatória**
  no refresh: valida assinatura → busca por jti → checa `revokedAt`/`expiresAt` →
  compara hash → revoga o antigo → emite novo par. Reuso de token revogado ⇒ 401.
- Novos claims no token exigem atualizar strategy + tipos + ARCHITECTURE.
- Endpoints de auth levam `@Throttle` mais rígido (10/min) — mantenha em rotas novas.

### users
- `PATCH /users/me` é parcial (DTO com opcionais validados; lat ∈ [-90,90],
  lng ∈ [-180,180]). Resposta nunca inclui `passwordHash`.

### files
- Só **presigned PUT** (300s) — a API nunca proxeia bytes de imagem. ContentType em
  allowlist (`image/jpeg|png|webp`); key gerada no servidor (`folder/uuid.ext`),
  nunca aceita do cliente. Folders válidos: `avatars`, `dogs`.
- **Teto de tamanho** (`MAX_UPLOAD_BYTES`, 20 MB): o cliente declara `contentLength`,
  o DTO valida o teto e a URL é assinada com `content-length` em `signableHeaders` —
  o storage recusa (403) corpo de tamanho diferente. Mexeu no teto? Atualize o
  espelho `maxUploadBytes` no app e o ARCHITECTURE §3.4.

### dogs
- Mutação só pelo dono (403 via service). Máx **6 fotos** por cão (400). `birthDate`
  futura ⇒ 400. Delete físico (cascade remove fotos). Regras novas de negócio: service.

### discovery
- Query geoespacial em `$queryRaw` com `Prisma.sql` composto (cláusulas de intent:
  BREEDING exige sexo oposto + `neutered=false`; FRIENDSHIP aceita FRIENDSHIP/BOTH;
  BOTH = união). Sempre `ST_DWithin` + `ORDER BY` distância (índice GIST funcional).
- **Filtros novos entram na SQL**, não em pós-processamento em memória.
- Segunda query Prisma busca dogs completos preservando a ordem por distância.
- `GET /discovery/search` (busca com filtros, §3.5.1): mesmo padrão — array de
  cláusulas `Prisma.sql` unidas por AND, query de `COUNT` + query da página
  (`LIMIT/OFFSET`), `ORDER BY distance_m ASC NULLS LAST` ou `created_at DESC`.
  Na busca o intent é filtro explícito (`BREEDING ⇒ IN (BREEDING, BOTH)`), SEM
  lógica de sexo oposto. Regras: `excludeSwiped` exige `dogId` (400); `radiusKm`/
  `orderBy=distance` exigem localização do usuário (400 LOCATION_REQUIRED);
  `dogId` de outro dono ⇒ 403, inexistente ⇒ 404. Filtro novo = nova cláusula SQL
  + validação no DTO + casos no spec + ARCHITECTURE §3.5.1 atualizado.

### swipes
- Sempre `$transaction`. Idempotência via unique `(swiperDogId, targetDogId)` (upsert;
  repetir swipe devolve estado atual). Match criado com **`dogAId < dogBId`**
  (invariante do schema). Emite `match.created` com MatchDto por perspectiva de cada dono.

### matches
- Toda operação valida membership do usuário no match (403). Listas novas usam
  **paginação por cursor** (id + `take limit+1` para `nextCursor`), não offset.
- `createMessage(userId, matchId, content)` é o **único caminho** de persistir
  mensagem — REST e WebSocket passam por ele.

### chat (gateway)
- Gateway **não persiste nada** direto: delega a services. Broadcast SEMPRE pelo
  handler do evento `message.created` (caminho único REST+WS — não emitir direto no
  `message:send`, senão duplica). `match:join` valida membership no banco.
- JWT verificado no handshake (`handshake.auth.token`); inválido ⇒ disconnect.
- Mantenha `@SkipThrottle()` no gateway e o early-return para contexto não-HTTP no
  `JwtAuthGuard` (guards globais não podem interferir em WS).
- Evento WS novo: documentar em ARCHITECTURE §3.7 e implementar no app na mesma tarefa.

### notifications
- Fila BullMQ `notifications`; listeners de eventos de domínio enfileiram jobs;
  processors **idempotentes** e com log. Integração FCM futura acontece no processor.

### health
- Terminus em `GET /health` (fora do prefixo `api`, `@Public`). Serviço crítico novo
  ganha indicator leve (sem chamadas caras).

## Testes

- Unit específico por service (`*.spec.ts` ao lado do arquivo), com `PrismaService`
  e `JwtService` mockados — siga `auth.service.spec.ts` / `swipes.service.spec.ts`.
- Cobrir caminhos de erro (401/403/409), não só o feliz. `npm test` roda sem infra.

## Checklist antes de concluir qualquer tarefa

`npm run build` + `npm run lint` + `npm test` verdes · migration criada/aplicada se o
schema mudou · Swagger refletindo DTOs · ARCHITECTURE.md sincronizado se o contrato
mudou · `.env.example` atualizado se env nova · sem `any` gratuito.
