# 🐾 DogMatch

**Tinder para cachorros** — donos conectam seus cães para cruzamento ou amizade.
Swipe, match e chat em tempo real.

| | |
|---|---|
| 📱 Mobile | Flutter (stable) · flutter_bloc · go_router · dio |
| 🖥️ Backend | NestJS 11 · Prisma · PostgreSQL + PostGIS · Redis · Socket.IO |
| 📦 Infra dev | Docker Compose (db, redis, MinIO) |

> Arquitetura completa, contrato da API e decisões técnicas: **[ARCHITECTURE.md](./ARCHITECTURE.md)**

## Pré-requisitos

- Docker + Docker Compose
- Node.js ≥ 22 (recomendado 24 LTS)
- Flutter SDK (canal stable) — instalado em `~/development/flutter` (já no PATH via `~/.bashrc`)
- Android Studio / Android SDK — necessário só para emulador e rodar no celular
  (guia em [mobile/README.md](./mobile/README.md#-rodando-no-seu-celular-android))

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

| E-mail | Senha |
|---|---|
| ana@demo.com | Senha123! |
| bruno@demo.com | Senha123! |
| carla@demo.com | Senha123! |

### Rodando no seu celular (Android)

Passo a passo completo (Android SDK, depuração USB, IP/firewall, fotos via MinIO) em
**[mobile/README.md → "Rodando no seu celular"](./mobile/README.md#-rodando-no-seu-celular-android)**. Resumo:

```bash
flutter run --dart-define=API_BASE_URL=http://SEU_IP_LOCAL:3000   # hostname -I
```

Para upload/exibição de fotos no aparelho, ajuste também `S3_ENDPOINT` e
`S3_PUBLIC_URL` no `backend/.env` com o mesmo IP (detalhes no guia).

## Comandos úteis (`make help`)

| Comando | Ação |
|---|---|
| `make up` / `make down` | Sobe/derruba a infra |
| `make nuke` | Derruba **e apaga volumes** (reset total) |
| `make api` | API em modo watch |
| `make migrate` / `make seed` | Prisma migrate / seed |
| `make studio` | Prisma Studio |
| `make test-backend` | Testes da API |
| `make analyze-mobile` | flutter analyze |

## Estrutura

```
├── backend/   → API NestJS (REST /api/v1 + WebSocket /chat)
├── mobile/    → App Flutter (Android/iOS)
└── docker-compose.yml
```
