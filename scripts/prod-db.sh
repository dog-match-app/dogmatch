#!/usr/bin/env bash
# Cliente psql efêmero do banco de PRODUÇÃO (VPS/Coolify), read-only por padrão.
#
#   ./scripts/prod-db.sh "SELECT ..."             # leitura (transação read-only)
#   ./scripts/prod-db.sh --write "UPDATE ..."     # escrita: EXIGE CONFIRM="EU CONFIRMO"
#
# Leitura é travada tecnicamente: a sessão nasce com
# default_transaction_read_only=on e o SQL é recusado se tentar desligar isso.
# Escrita só roda com --write E a env CONFIRM="EU CONFIRMO" — que representa a
# confirmação explícita do Rodrigo na conversa; sem ela o script aborta.
#
# Acesso: SSH na VPS + docker exec no container do Postgres (a porta 5432 não é
# pública de propósito). Requer a chave ~/.ssh/dogmatch-prod-db autorizada na VPS.
set -euo pipefail

SSH_KEY="${PROD_SSH_KEY:-$HOME/.ssh/dogmatch-prod-db}"
SSH_TARGET="${PROD_SSH:-root@178.104.17.16}"
ENV_FILE="$(dirname "$0")/../backend/.env.coolify"

MODE="read"
if [[ "${1:-}" == "--write" ]]; then
  MODE="write"
  shift
fi
SQL="${1:-}"
if [[ -z "$SQL" ]]; then
  echo "uso: $0 [--write] \"SQL\"" >&2
  exit 2
fi

PG_CONTAINER="$(grep -oP 'DATABASE_URL="[^"]*@\K[^:]+' "$ENV_FILE")"
PG_DB="$(grep -oP 'DATABASE_URL="[^"]*/\K[^?"]+' "$ENV_FILE")"

if [[ "$MODE" == "read" ]]; then
  if echo "$SQL" | grep -qiE 'transaction_read_only|set\s+session|pg_terminate|pg_cancel'; then
    echo "ERRO: tentativa de escapar do modo read-only recusada." >&2
    exit 3
  fi
  PGOPTS='-c default_transaction_read_only=on'
else
  if [[ "${CONFIRM:-}" != "EU CONFIRMO" ]]; then
    echo "ERRO: escrita exige confirmação explícita do Rodrigo na conversa," >&2
    echo "      refletida em CONFIRM=\"EU CONFIRMO\" $0 --write \"SQL\"" >&2
    exit 4
  fi
  PGOPTS=''
fi

exec ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8 "$SSH_TARGET" \
  "docker exec -i -e PGOPTIONS='$PGOPTS' '$PG_CONTAINER' \
     psql -U postgres -d '$PG_DB' -v ON_ERROR_STOP=1 -P pager=off -c \"\$(cat)\"" <<<"$SQL"
