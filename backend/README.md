# DogMatch API (NestJS)

API REST + WebSocket do DogMatch. Contrato completo em [`../ARCHITECTURE.md`](../ARCHITECTURE.md).

## Rodar em dev

```bash
# na raiz do repo: sobe postgres+postgis, redis e minio
docker compose up -d db redis minio minio-setup

cd backend
cp .env.example .env   # já vem pronto para o compose local
npm install
npx prisma migrate dev  # aplica migrations (inclui extensão PostGIS)
npx prisma db seed      # dados demo (ana/bruno/carla@demo.com, senha Senha123!)
npm run start:dev
```

- API: `http://localhost:3000/api/v1` · Health: `http://localhost:3000/health`
- Swagger: `http://localhost:3000/api/docs` (bearer auth)
- WebSocket: namespace `/chat`, handshake `auth: { token: <accessToken> }`

## Comandos úteis

| Comando | Descrição |
|---|---|
| `npm run build` | Compila para `dist/` |
| `npm run lint` | ESLint com `--fix` |
| `npm test` | Testes unitários (Jest) |
| `npx prisma migrate dev` | Cria/aplica migrations |
| `npx prisma db seed` | Reaplica o seed (idempotente) |
| `npx prisma studio` | UI do banco |

## Produção

Imagem Docker multi-stage (`Dockerfile`): `docker build -t dogmatch-api .`
Migrations em deploy: `npx prisma migrate deploy`.
