# Deploy do backend no Coolify (VPS)

Guia para deixar a API pública e permitir que outras pessoas testem o app.
O repositório já está preparado: o `Dockerfile` do backend roda
`prisma migrate deploy` automaticamente no boot e a API ativa `trust proxy`
em produção (IP real atrás do Traefik do Coolify).

## 0. Pré-requisito: repositório no GitHub

O Coolify faz deploy a partir de um repositório git:

```bash
# crie um repositório (privado ou público) em github.com/new, depois:
cd ~/Documents/flutter/dogmatch
git remote add origin git@github.com:SEU_USUARIO/dogmatch.git
git push -u origin main
```

## 1. Serviços de apoio (no mesmo projeto do Coolify)

Crie um **Project** (ex.: `dogmatch`) e dentro dele:

### PostgreSQL + PostGIS
- **+ New → Database → PostgreSQL**.
- Em **Image**, troque para `postgis/postgis:16-3.4` (o discovery depende do PostGIS).
- Anote usuário/senha/db gerados. **Não** exponha porta pública (a API acessa pela
  rede interna do Coolify).

### Redis
- **+ New → Database → Redis** (padrão já serve; sem porta pública).

### MinIO (fotos)
- **+ New → Service → MinIO**.
- Defina um FQDN público para a **porta 9000 (API S3)** — ex.:
  `https://media.SEUDOMINIO.com` (o Coolify emite o certificado sozinho).
  O console (9001) pode ficar sem domínio público.
- Anote `MINIO_ROOT_USER`/`MINIO_ROOT_PASSWORD`.
- Depois de subir, abra o console do MinIO (via FQDN do console ou port-forward),
  crie o bucket **`dogmatch-media`** e marque o acesso anônimo de leitura
  (*Access Policy → public/download*) — mesmo papel do `minio-setup` local.

> Alternativa sem MinIO: qualquer S3 (AWS, Cloudflare R2, Backblaze). Só ajuste
> as envs `S3_*` — o código usa o SDK padrão da AWS.

## 2. A API

- **+ New → Application → (seu repositório GitHub)**.
- **Build Pack**: `Dockerfile` · **Base Directory**: `/backend` (o Dockerfile está lá).
- **Port**: `3000`. **Healthcheck**: caminho `/health`.
- **Domains**: `https://api.SEUDOMINIO.com` (sem domínio próprio, use o domínio
  `*.sslip.io` que o Coolify gera).
- **Environment Variables** (aba Environment):

```env
NODE_ENV=production
PORT=3000
# host/credenciais internos mostrados pelo Coolify no recurso do Postgres:
DATABASE_URL=postgresql://USUARIO:SENHA@HOST_INTERNO_DO_PG:5432/DB?schema=public
REDIS_URL=redis://HOST_INTERNO_DO_REDIS:6379
JWT_ACCESS_SECRET=<64+ chars aleatórios — openssl rand -hex 32>
JWT_ACCESS_TTL=15m
JWT_REFRESH_SECRET=<outro valor aleatório>
JWT_REFRESH_TTL=30d
# endpoint INTERNO do MinIO para assinar? NÃO: use o PÚBLICO — a URL assinada
# embute o host e o celular precisa alcançá-lo:
S3_ENDPOINT=https://media.SEUDOMINIO.com
S3_REGION=us-east-1
S3_ACCESS_KEY=<MINIO_ROOT_USER>
S3_SECRET_KEY=<MINIO_ROOT_PASSWORD>
S3_BUCKET=dogmatch-media
S3_PUBLIC_URL=https://media.SEUDOMINIO.com/dogmatch-media
CORS_ORIGINS=*
THROTTLE_TTL=60000
THROTTLE_LIMIT=100
```

- **Deploy**. O container roda `prisma migrate deploy` no boot (cria as tabelas)
  e sobe a API. Confira `https://api.SEUDOMINIO.com/health` e `/api/docs`.

Observações:
- **WebSocket (chat)** funciona pelo mesmo domínio — o proxy do Coolify (Traefik)
  faz upgrade de conexão sem config extra.
- **Seed de demonstração é opcional em produção** (o container não tem ts-node).
  Para dados de demo, crie contas reais pelo app; se quiser mesmo o seed, rode-o
  da sua máquina apontando `DATABASE_URL` para o Postgres via um túnel SSH.
- Segredos: gere JWTs fortes (`openssl rand -hex 32`) — nunca use os valores de dev.

## 3. APK público para os testadores

O APK embute a URL da API em build time:

```bash
cd mobile && flutter build apk --release --dart-define=API_BASE_URL=https://api.SEUDOMINIO.com
```

Distribua o `app-release.apk` (Drive, grupo, etc.). Como a API é `https`, o app
não depende de cleartext e funciona em qualquer rede. Cada atualização = novo
build + reenvio (roadmap: Firebase App Distribution para automatizar).

## 4. Atualizações

`git push` na `main` → o Coolify rebuilda e redeploya (ative o auto-deploy por
webhook na aplicação). Migrations novas rodam sozinhas no boot.
