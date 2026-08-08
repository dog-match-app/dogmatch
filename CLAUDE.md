# CLAUDE.md — DogMatch (monorepo)

App "Tinder para cachorros": donos conectam cães para cruzamento ou amizade
(swipe → match → chat em tempo real).

## Mapa

- `backend/` — API NestJS 11 (REST `/api/v1` + WebSocket `/chat`). Padrões: **`backend/CLAUDE.md`**.
- `mobile/` — App Flutter (Android/iOS), flutter_bloc. Padrões: **`mobile/CLAUDE.md`**.
- `ARCHITECTURE.md` — **fonte da verdade**: contrato da API v1, schema Prisma, eventos WS, envs, decisões.
- `docker-compose.yml` + `Makefile` — infra dev (Postgres+PostGIS, Redis, MinIO).

## Regra central do monorepo

Qualquer mudança de contrato (endpoint, DTO, evento WebSocket, env) **começa no
`ARCHITECTURE.md`** e é refletida nos DOIS lados (backend e mobile) na mesma tarefa.
Os lados nunca podem divergir do documento.

## Comandos essenciais

- `make up` sobe a infra; `make help` lista o resto.
- API: `cd backend && npm run start:dev` → Swagger em `http://localhost:3000/api/docs`.
- App (emulador Android): `cd mobile && flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000`.
- App (celular físico): guia completo em `mobile/README.md` ("Rodando no seu celular").
- Usuários seed: ana@demo.com · bruno@demo.com · carla@demo.com — senha `Senha123!`.

## Ambiente desta máquina

- Flutter SDK em `~/development/flutter` (canal stable), no PATH via `~/.bashrc`/`~/.profile`.
- Android SDK em `~/Android/Sdk` (cmdline-tools + platforms 35/36 + build-tools +
  platform-tools/adb) e JDK 21 Temurin em `~/development/jdk-21` — ambos registrados
  no Flutter via `flutter config --android-sdk/--jdk-dir`. Sem emulador instalado.
- Celular de testes: **Xiaomi que bloqueia `adb install`** — o fluxo é `make apk` +
  `make push-apk` e instalação manual pelo gerenciador de arquivos (mobile/README.md).
- Node 24 · Docker Compose v5 · infra local nos containers `dogmatch-db|redis|minio`.

## Convenções gerais

- Commits: Conventional Commits — `feat|fix|refactor|chore|docs(escopo): descrição`;
  escopos: `backend`, `mobile`, `infra`, `docs`.
- Documentação em PT-BR; código, identificadores e mensagens de erro da API em inglês;
  strings de UI do app em PT-BR.
- Definition of done de qualquer tarefa: backend `lint + test + build` verdes;
  mobile `build_runner + analyze (zero issues) + test` verdes — o CI cobra exatamente isso.
