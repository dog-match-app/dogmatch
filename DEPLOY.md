# Deploy do backend no Coolify (VPS)

Guia para deixar a API pública e permitir que outras pessoas testem o app.
O repositório já está preparado: o `Dockerfile` do backend roda
`prisma migrate deploy` automaticamente no boot e a API ativa `trust proxy`
em produção.

Há dois cenários — escolha o seu:

| | **A. Só o IP da VPS** (sem domínio) | **B. Com domínio próprio** |
|---|---|---|
| URLs | `http://IP:3000` (API) · `http://IP:9000` (fotos) | `https://api.seu.com` · `https://media.seu.com` |
| HTTPS | ❌ não confiável sem domínio (Let's Encrypt não emite para IP puro, e domínios `sslip.io` vivem estourando o rate limit global) | ✅ automático pelo Coolify |
| Exposição | portas mapeadas direto no container | proxy (Traefik) por domínio |
| Uso | testes com amigos | qualquer coisa mais séria |

> **Aviso do cenário A**: HTTP = tráfego sem criptografia (senhas visíveis para
> quem estiver no caminho). Ok para uma rodada de testes; migre para o cenário B
> antes de qualquer uso real. O app já funciona com HTTP (`usesCleartextTraffic`
> está habilitado no manifest — remova-o só quando for 100% HTTPS).

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
- **+ New → Service → MinIO**. Anote `MINIO_ROOT_USER`/`MINIO_ROOT_PASSWORD`.
- **Cenário A (só IP)**: em **Ports Mappings** do serviço, mapeie `9000:9000`
  (API S3 pública em `http://IP_DA_VPS:9000`). Libere a porta no firewall da VPS
  (`sudo ufw allow 9000/tcp` e/ou no painel do provedor).
- **Cenário B (domínio)**: defina um FQDN público para a porta 9000 — ex.:
  `https://media.SEUDOMINIO.com` (certificado automático).
- Depois de subir, abra o console do MinIO (porta 9001 — exponha temporariamente
  ou use um túnel SSH `ssh -L 9001:localhost:9001 usuario@IP`), crie o bucket
  **`dogmatch-media`** e marque leitura anônima (*Access Policy → download*) —
  mesmo papel do `minio-setup` local.

> Alternativa sem MinIO: qualquer S3 (AWS, Cloudflare R2, Backblaze) — R2 tem
> HTTPS público de graça e resolve as fotos mesmo no cenário A. Só ajuste as `S3_*`.

## 2. A API

- **+ New → Application → (seu repositório GitHub)**.
- **Build Pack**: `Dockerfile` · **Base Directory**: `/backend`.
- **Port**: `3000`. **Healthcheck**: caminho `/health`.
- **Exposição**:
  - **Cenário A**: em **Ports Mappings**, mapeie `3000:3000` e libere a porta no
    firewall da VPS (`sudo ufw allow 3000/tcp`). A API fica em `http://IP_DA_VPS:3000`.
  - **Cenário B**: em **Domains**, `https://api.SEUDOMINIO.com`.
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
# S3_ENDPOINT/S3_PUBLIC_URL: SEMPRE o endereço que o CELULAR alcança — a URL
# presigned embute esse host (mesma lição do localhost no dev):
#   Cenário A:
S3_ENDPOINT=http://IP_DA_VPS:9000
S3_PUBLIC_URL=http://IP_DA_VPS:9000/dogmatch-media
#   Cenário B (troque as duas acima por):
# S3_ENDPOINT=https://media.SEUDOMINIO.com
# S3_PUBLIC_URL=https://media.SEUDOMINIO.com/dogmatch-media
S3_REGION=us-east-1
S3_ACCESS_KEY=<MINIO_ROOT_USER>
S3_SECRET_KEY=<MINIO_ROOT_PASSWORD>
S3_BUCKET=dogmatch-media
CORS_ORIGINS=*
THROTTLE_TTL=60000
THROTTLE_LIMIT=100
```

- **Deploy**. O container roda `prisma migrate deploy` no boot (cria as tabelas)
  e sobe a API. Confira `http://IP_DA_VPS:3000/health` (ou o domínio) e `/api/docs`.

Observações:
- **WebSocket (chat)** funciona nos dois cenários (no A, direto na porta; no B,
  o Traefik faz o upgrade sem config extra).
- **Seed de demonstração é opcional em produção** (o container não tem ts-node).
  Para dados de demo, crie contas reais pelo app; se quiser mesmo o seed, rode-o
  da sua máquina apontando `DATABASE_URL` para o Postgres via túnel SSH.
- Segredos: gere JWTs fortes (`openssl rand -hex 32`) — nunca use os valores de dev.

## 3. APK público para os testadores

O APK embute a URL da API em build time:

```bash
# Cenário A (só IP):
cd mobile && flutter build apk --release --dart-define=API_BASE_URL=http://IP_DA_VPS:3000
# Cenário B (domínio):
cd mobile && flutter build apk --release --dart-define=API_BASE_URL=https://api.SEUDOMINIO.com
```

Distribua o `app-release.apk` (Drive, grupo, etc.). Cada atualização = novo
build + reenvio (roadmap: Firebase App Distribution para automatizar).

## 4. Atualizações

`git push` na `main` → o Coolify rebuilda e redeploya (ative o auto-deploy por
webhook na aplicação). Migrations novas rodam sozinhas no boot.

## 5. Quando comprar um domínio (migração A → B)

1. Aponte `api.` e `media.` para o IP da VPS (registros A).
2. No Coolify: adicione os Domains na API e no MinIO e remova os Ports Mappings.
3. Troque `S3_ENDPOINT`/`S3_PUBLIC_URL` para as URLs `https` e redeploye.
4. Regere o APK com a URL `https` e, aí sim, remova o `usesCleartextTraffic`
   do manifest. Fotos antigas continuam funcionando se você mantiver o mesmo
   bucket (as URLs salvas no banco guardam o host antigo — um `UPDATE` simples
   nos campos `url` resolve, ou reste as fotos de teste).
