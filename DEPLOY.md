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

**Opção 3 — Garage** (self-hosted ativo, alternativa ao MinIO): projeto leve, feito
para rodar fora de datacenter, consome pouca RAM. **Só faça sentido com domínio
(cenário B)**: o Garage **não permite acesso anônimo na API S3** — a leitura pública
sai pelo endpoint web (porta 3902), que roteia **por Host**, então um `S3_PUBLIC_URL`
com IP puro não funciona. Com domínio, fica assim:

1. Gere dois segredos: `openssl rand -hex 32` (um para `rpc_secret`, outro para
   `admin_token`).
2. **+ New → Docker Compose**:

   ```yaml
   services:
     garage:
       image: dxflrs/garage:v1.0.1
       volumes:
         - garage_meta:/var/lib/garage/meta
         - garage_data:/var/lib/garage/data
         - ./garage.toml:/etc/garage.toml
       ports:
         - "3900:3900"   # API S3
         - "3902:3902"   # endpoint web (leitura pública)
       deploy:
         resources:
           limits:
             memory: 512M
   volumes:
     garage_meta:
     garage_data:
   ```

   Com `garage.toml` (arquivo montado, no editor de arquivos do Coolify):

   ```toml
   metadata_dir = "/var/lib/garage/meta"
   data_dir = "/var/lib/garage/data"
   db_engine = "sqlite"
   replication_factor = 1          # nó único

   rpc_bind_addr = "[::]:3901"
   rpc_public_addr = "127.0.0.1:3901"
   rpc_secret = "<openssl rand -hex 32>"

   [s3_api]
   s3_region = "garage"
   api_bind_addr = "[::]:3900"
   root_domain = ".s3.SEUDOMINIO.com"

   [s3_web]
   bind_addr = "[::]:3902"
   root_domain = ".web.SEUDOMINIO.com"
   index = "index.html"

   [admin]
   api_bind_addr = "[::]:3903"
   admin_token = "<outro openssl rand -hex 32>"
   ```

3. Inicialize o layout e crie bucket/chave (uma vez, via terminal do container):

   ```bash
   garage status                                   # copie o ID do nó
   garage layout assign -z dc1 -c 10G <ID_DO_NÓ>
   garage layout apply --version 1
   garage bucket create dogmatch-media
   garage key create dogmatch-key                  # anote Key ID e Secret
   garage bucket allow --read --write dogmatch-media --key dogmatch-key
   garage bucket website --allow dogmatch-media    # leitura pública via web
   ```

4. No Coolify, aponte `media.SEUDOMINIO.com` para a **porta 3902** (web) e
   `s3.SEUDOMINIO.com` para a **3900** (API S3). Envs:

   ```env
   S3_ENDPOINT=https://s3.SEUDOMINIO.com
   S3_REGION=garage
   S3_ACCESS_KEY=<Key ID>
   S3_SECRET_KEY=<Secret>
   S3_BUCKET=dogmatch-media
   S3_PUBLIC_URL=https://dogmatch-media.web.SEUDOMINIO.com
   ```

   (O host público é `<bucket>.web.<root_domain>` — é assim que o Garage sabe qual
   bucket servir. Sem DNS curinga, crie o registro desse subdomínio específico.)

> Resumo da escolha: **R2** = zero manutenção e HTTPS de graça, inclusive sem
> domínio · **MinIO** = tudo na sua VPS, funciona com IP puro · **Garage** = leve e
> self-hosted moderno, mas exige domínio pela ausência de acesso anônimo no S3.

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
### Onde achar os hosts internos do Postgres e do Redis

Você **não monta esses endereços na mão** — o Coolify já os entrega prontos:

1. Abra o recurso do **Postgres** no Coolify. Na aba principal há os campos
   **"Postgres URL (internal)"** e "Postgres URL (external)". **Copie a internal** —
   ela já vem completa, com usuário, senha, host e porta, algo como
   `postgresql://postgres:SENHA@postgresql-abc123def456:5432/postgres`.
   Esse `postgresql-abc123def456` é o nome do container (o sufixo é o UUID do
   recurso) e funciona como hostname dentro da rede Docker.
2. Mesma coisa no recurso do **Redis**: copie a **"Redis URL (internal)"**
   (`redis://default:SENHA@redis-xyz789:6379`).
3. Cole nas envs da API. Só ajuste o final da URL do Postgres para o schema:
   `...:5432/postgres?schema=public`.

> **Sobre o `/postgres` no fim da URL**: é o nome do banco dentro do servidor (o
> `dogmatch` do ambiente local veio do nosso compose). Pode manter o do Coolify —
> nada no código depende desse nome e o Prisma cria as tabelas onde a URL apontar.
> Se preferir um banco chamado `dogmatch`, defina `POSTGRES_DB=dogmatch` **antes do
> primeiro deploy** do Postgres (depois de inicializado o volume, a variável é
> ignorada) ou crie-o depois:
> `docker exec -it postgresql-<uuid> psql -U postgres -c "CREATE DATABASE dogmatch;"`.
> Atenção: `prisma migrate deploy` cria tabelas, **não bancos** — apontar para um
> banco inexistente falha o deploy.

> Alternativa: no terminal da VPS, `docker ps --format '{{.Names}}'` lista os
> containers — os nomes com prefixo `postgresql-`/`redis-` são exatamente esses hosts.

**⚠️ O erro mais comum**: a aplicação não enxerga o banco (`getaddrinfo ENOTFOUND`
ou "connection refused") porque **aplicações e bancos ficam em redes Docker
separadas** por padrão. Solução: na aplicação, aba **Advanced → ative "Connect to
Predefined Network"** e redeploy. Com isso a API entra na rede compartilhada do
Coolify e passa a resolver os nomes dos containers de banco.

### Gerando os segredos JWT

Rode no seu terminal (Linux/macOS) e cole os valores nas envs. **Um valor
diferente para cada** — reaproveitar o mesmo segredo nos dois anula a separação
entre access e refresh token:

```bash
# imprime as duas linhas já prontas para colar no Coolify:
echo "JWT_ACCESS_SECRET=$(openssl rand -hex 32)"
echo "JWT_REFRESH_SECRET=$(openssl rand -hex 32)"
```

Sem o `openssl` à mão, qualquer um destes serve:

```bash
python3 -c "import secrets; print(secrets.token_hex(32))"   # 64 chars hex
head -c 48 /dev/urandom | base64                            # 64 chars base64
```

Cada comando gera 32 bytes de entropia (64 caracteres em hex) — bem acima do
mínimo recomendado para HS256, que é o algoritmo usado pelo `@nestjs/jwt` aqui.

Cuidados:
- **Nunca** reutilize os valores de desenvolvimento (`dev-access-secret-change-me`)
  em produção: eles estão versionados no repositório, ou seja, são públicos.
- Não cole segredos em chats, issues ou prints — se um vazar, gere outro e
  redeploye (todos os usuários simplesmente refazem login).
- Trocar `JWT_ACCESS_SECRET` invalida os access tokens em circulação; trocar
  `JWT_REFRESH_SECRET` desloga todo mundo. É exatamente o que se quer em caso de
  suspeita de vazamento.

- **Environment Variables** (aba Environment):

```env
NODE_ENV=production
PORT=3000
# copie as "URL (internal)" dos recursos (ver acima); exemplo do formato:
DATABASE_URL=postgresql://postgres:SENHA@postgresql-abc123def456:5432/postgres?schema=public
REDIS_URL=redis://default:SENHA@redis-xyz789:6379
JWT_ACCESS_SECRET=<saída do openssl — ver "Gerando os segredos JWT" acima>
JWT_ACCESS_TTL=15m
JWT_REFRESH_SECRET=<outra saída, diferente da anterior>
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
| MinIO/Garage | **512M** | — (apenas se auto-hospedado; com R2 esta linha some e o total cai para ~2 GB) |

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
