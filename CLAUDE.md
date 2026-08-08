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

## Commits (Conventional Commits — estrito)

Commits são criados pelo Claude a cada feature/entrega concluída e validada
(autorizado pelo Rodrigo em 2026-08-08). `git push` apenas com pedido explícito.

Formato obrigatório: `tipo(escopo): descrição`

- **Tipos**: `feat`, `fix`, `refactor`, `perf`, `test`, `docs`, `chore`, `ci`, `build`.
- **Escopo obrigatório** quando o commit toca um único lado: `backend`, `mobile` ou
  `infra`. Sem escopo somente para mudanças da raiz/atravessadas e para `docs`.
- **Descrição**: pt-br (acentos ok), minúsculas, verbo no imperativo, sem ponto
  final, ≤ 72 caracteres. Nada de sufixos entre parênteses no lugar do escopo.
- **Corpo** (opcional): bullets `-` com o quê/por quê.
- **Um commit por mudança lógica** — backend e mobile da mesma feature são commits
  separados, cada um com seu escopo.
- **Breaking change** de contrato: `tipo(escopo)!: ...` + rodapé `BREAKING CHANGE: ...`.
- **Sem trailers automáticos**: NUNCA adicionar `Co-Authored-By` (nem rodapés
  similares de coautoria/geração) às mensagens de commit.

Exemplos válidos: `feat(backend): perfil público do dono` ·
`fix(mobile): máscara de data aceita ano bissexto` · `docs: contrato de denúncias`.

## Convenções gerais

- Documentação em PT-BR; código, identificadores e mensagens de erro da API em inglês;
  strings de UI do app em PT-BR.
- Definition of done de qualquer tarefa: backend `lint + test + build` verdes;
  mobile `build_runner + analyze (zero issues) + test` verdes — o CI cobra exatamente isso.
- UI nunca pressupõe conhecimento interno do app: rótulos autoexplicativos (nada de
  "Ambos" solto), tags/valores sempre com indicador da categoria a que pertencem, e
  inputs que aceitam digitação além de pickers (ex.: data com máscara + calendário).
