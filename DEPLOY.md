# Deploy do backend no Coolify (VPS)

Guia para deixar a API pública e permitir que outras pessoas testem o app.
O repositório já está preparado: o `Dockerfile` do backend roda
`prisma migrate deploy` automaticamente no boot e a API ativa `trust proxy`
em produção.

Há dois cenários — escolha o seu:

| | **A. Só o IP da VPS** (sem domínio) | **B. Com domínio próprio** |
|---|---|---|
| URLs | `http://IP:3333` (API) · fotos: `https://pub-….r2.dev` (R2) ou `http://IP:9000` (MinIO) | `https://api.seu.com` · `https://media.seu.com` |
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

### Armazenamento de fotos (S3)

> O template de MinIO **foi removido do catálogo do Coolify** ("service removed
> from Coolify's one-click service catalog"). Duas rotas, ambas compatíveis com o
> código sem nenhuma mudança (o backend usa o SDK S3 padrão):

**Opção 1 — Cloudflare R2 (recomendada)**: grátis até 10 GB, não gasta a RAM da
VPS e as fotos saem com **HTTPS mesmo no cenário A**.

1. Crie uma conta na Cloudflare → **R2 Object Storage** → *Create bucket* →
   nome `dogmatch-media`.
2. No bucket, aba *Settings* → **Public access → Allow (r2.dev subdomain)** —
   anote a URL pública (`https://pub-XXXX.r2.dev`).
3. Em *R2 → API Tokens* (ou *Manage API tokens*), crie um token **Object Read &
   Write** restrito ao bucket — anote `Access Key ID`, `Secret Access Key` e o
   endpoint S3 da conta (`https://<ACCOUNT_ID>.r2.cloudflarestorage.com`).
4. Envs correspondentes na API (usadas na seção 2):

   ```env
   S3_ENDPOINT=https://<ACCOUNT_ID>.r2.cloudflarestorage.com
   S3_REGION=auto
   S3_ACCESS_KEY=<Access Key ID>
   S3_SECRET_KEY=<Secret Access Key>
   S3_BUCKET=dogmatch-media
   S3_PUBLIC_URL=https://pub-XXXX.r2.dev
   ```

   O upload presigned vai direto do celular para a Cloudflare (HTTPS); a leitura
   pública sai pela URL `r2.dev`.

**Opção 2 — MinIO por conta própria** (tudo na VPS): a imagem Docker continua
disponível; suba-a como **+ New → Docker Compose** colando:

```yaml
services:
  minio:
    # tag fixada: último ciclo de releases com console web completo
    image: minio/minio:RELEASE.2025-04-22T22-12-26Z
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: dogmatch
      MINIO_ROOT_PASSWORD: TROQUE-ESTA-SENHA
    ports:
      - "9000:9000"   # se a 9000 estiver ocupada na VPS: "9002:9000" (e ajuste as envs S3_*)
    volumes:
      - minio_data:/data
    deploy:
      resources:
        limits:
          memory: 512M
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 5s
      timeout: 5s
      retries: 12
  minio-setup:
    image: minio/mc
    depends_on:
      minio:
        condition: service_healthy
    environment:
      MINIO_ROOT_USER: dogmatch
      MINIO_ROOT_PASSWORD: TROQUE-ESTA-SENHA
    entrypoint: >
      /bin/sh -c "
      mc alias set local http://minio:9000 $$MINIO_ROOT_USER $$MINIO_ROOT_PASSWORD &&
      mc mb --ignore-existing local/dogmatch-media &&
      mc anonymous set download local/dogmatch-media"
volumes:
  minio_data:
```

O `minio-setup` cria o bucket com leitura pública e sai. Libere a porta escolhida
no firewall (`sudo ufw allow 9000/tcp`) e use nas envs:
`S3_ENDPOINT=http://IP_DA_VPS:9000` · `S3_PUBLIC_URL=http://IP_DA_VPS:9000/dogmatch-media`
(no cenário B: FQDN público na porta 9000 e URLs `https`). Se a tag fixada sumir,
qualquer `RELEASE.2025-04*` de hub.docker.com/r/minio/minio/tags serve.

> Outras alternativas self-hosted ativas, se preferir fugir do MinIO: Garage
> (leve, ótimo p/ VPS pequena) e SeaweedFS — ambos S3-compatible.

## 2. A API

- **+ New → Application → (seu repositório GitHub)**.
- **Build Pack**: `Dockerfile` · **Base Directory**: `/backend`.
- **Port**: `3000`. **Healthcheck**: caminho `/health`.
- **Exposição**:
  - **Cenário A**: em **Ports Mappings**, mapeie **`3333:3000`** (host:container —
    a porta 3000 da VPS costuma estar ocupada por outros processos; `3333` é só o
    lado público, troque por qualquer porta livre: confira com `ss -ltn`). Libere no
    firewall (`sudo ufw allow 3333/tcp`). A API fica em `http://IP_DA_VPS:3333`.
    **Dentro do container nada muda**: `PORT=3000` permanece.
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
# Bloco S3_*: copie da opção de storage escolhida na seção 1 (R2 ou MinIO).
# Regra de ouro: S3_ENDPOINT/S3_PUBLIC_URL usam SEMPRE um endereço que o
# CELULAR alcança — a URL presigned embute esse host (lição do localhost no dev).
#   R2:    S3_ENDPOINT=https://<ACCOUNT_ID>.r2.cloudflarestorage.com · S3_REGION=auto
#          S3_PUBLIC_URL=https://pub-XXXX.r2.dev
#   MinIO: S3_ENDPOINT=http://IP_DA_VPS:9000 · S3_REGION=us-east-1
#          S3_PUBLIC_URL=http://IP_DA_VPS:9000/dogmatch-media
S3_ENDPOINT=<da opção escolhida>
S3_REGION=<da opção escolhida>
S3_ACCESS_KEY=<da opção escolhida>
S3_SECRET_KEY=<da opção escolhida>
S3_BUCKET=dogmatch-media
S3_PUBLIC_URL=<da opção escolhida>
CORS_ORIGINS=*
THROTTLE_TTL=60000
THROTTLE_LIMIT=100
```

- **Deploy**. O container roda `prisma migrate deploy` no boot (cria as tabelas)
  e sobe a API. Confira `http://IP_DA_VPS:3333/health` (ou o domínio) e `/api/docs`.

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
# Cenário A (só IP — use a porta do host escolhida no mapeamento):
cd mobile && flutter build apk --release --dart-define=API_BASE_URL=http://IP_DA_VPS:3333
# Cenário B (domínio):
cd mobile && flutter build apk --release --dart-define=API_BASE_URL=https://api.SEUDOMINIO.com
```

Distribua o `app-release.apk` (Drive, grupo, etc.). Cada atualização = novo
build + reenvio (roadmap: Firebase App Distribution para automatizar).

## 4. Atualizações

`git push` na `main` → o Coolify rebuilda e redeploya (ative o auto-deploy por
webhook na aplicação). Migrations novas rodam sozinhas no boot.

## 5. Limites de memória (VPS de 8 GB → sistema todo ≤ 3 GB)

Orçamento recomendado (soma dos limites ≈ **2,5 GB**, sobrando folga dentro dos
3 GB e deixando o resto da VPS livre):

| Serviço | Limite do container | Ajuste interno (para caber no limite) |
|---|---|---|
| API (NestJS) | **768M** | env `NODE_OPTIONS=--max-old-space-size=512` (heap do Node em 512 MB; o resto é margem p/ buffers) |
| PostgreSQL | **1G** | conf abaixo (Postgres não enxerga o limite do cgroup sozinho) |
| Redis | **256M** | `maxmemory 200mb` + `maxmemory-policy noeviction` |
| MinIO | **512M** | — (apenas se auto-hospedado; com R2 esta linha some e o total cai para ~2 GB) |

Como aplicar no Coolify:

- **API (Application)**: aba **Advanced → Resource Limits** (ou o campo *Custom
  Docker Run Options*): **Memory Limit** `768m` e **Memory Swap Limit** `768m`
  (swap = limite ⇒ o container não empurra para swap). Equivalente em opções
  cruas: `--memory=768m --memory-swap=768m`. Adicione também a env
  `NODE_OPTIONS=--max-old-space-size=512` na aba Environment.
- **PostgreSQL (Database)**: Resource Limits/Custom Docker Options com
  `--memory=1g --memory-swap=1g`, e no campo **Custom PostgreSQL Configuration**:

  ```conf
  shared_buffers = 256MB
  effective_cache_size = 512MB
  work_mem = 8MB
  maintenance_work_mem = 64MB
  max_connections = 30
  ```

  (Opcional: limite o pool do Prisma acrescentando `&connection_limit=10` ao
  final da `DATABASE_URL` — bem abaixo dos 30 do Postgres.)
- **Redis (Database)**: `--memory=256m --memory-swap=256m` e, na configuração
  custom do Redis (ou argumentos de start):

  ```conf
  maxmemory 200mb
  maxmemory-policy noeviction
  ```

  > `noeviction` de propósito: o Redis guarda filas do BullMQ — política de
  > eviction "lru" descartaria jobs silenciosamente. Com 200 MB há espaço de
  > sobra para filas + adapter do socket.io neste porte de app.
- **MinIO (Service)**: edite o Docker Compose do serviço no Coolify e adicione ao
  serviço do minio:

  ```yaml
  deploy:
    resources:
      limits:
        memory: 512M
  ```

Verificação e comportamento:

- Na VPS, `docker stats` mostra uso vs. limite por container em tempo real.
- Se um container estourar o limite, o kernel o mata (OOM) e o Coolify/Docker o
  reinicia (restart policy) — para a API isso é um restart limpo; para o Postgres,
  a conf acima existe justamente para ele se manter longe do teto.
- Esses números aguentam tranquilamente uma rodada de testes com dezenas de
  usuários; se o discovery começar a lentear com muita gente, o primeiro upgrade
  é subir o limite do Postgres (e `shared_buffers` junto, ~25% do novo limite).

## 6. Quando comprar um domínio (migração A → B)

1. Aponte `api.` e `media.` para o IP da VPS (registros A).
2. No Coolify: adicione os Domains na API e no MinIO e remova os Ports Mappings.
3. Troque `S3_ENDPOINT`/`S3_PUBLIC_URL` para as URLs `https` e redeploye.
4. Regere o APK com a URL `https` e, aí sim, remova o `usesCleartextTraffic`
   do manifest. Fotos antigas continuam funcionando se você mantiver o mesmo
   bucket (as URLs salvas no banco guardam o host antigo — um `UPDATE` simples
   nos campos `url` resolve, ou reste as fotos de teste).
