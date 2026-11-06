#!/usr/bin/env bash
# Ejecuta docker compose de un ambiente: base común + override del ambiente.
#   ./deploy/compose/compose.sh dev up -d --wait
#   IMAGE_TAG=1.2.0 ./deploy/compose/compose.sh prod pull
# Secretos: deploy/compose/<env>/.env (si no existe, deploy/compose/.env). Nunca se versionan.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_NAME="${1:?Ambiente: dev, stage o prod}"
shift
case "$ENV_NAME" in dev|stage|prod) ;; *) echo "Ambiente inválido: $ENV_NAME" >&2; exit 1 ;; esac

ENV_FILE="$DIR/$ENV_NAME/.env"
[[ -f "$ENV_FILE" ]] || ENV_FILE="$DIR/.env"
[[ -f "$ENV_FILE" ]] || { echo "Falta $DIR/$ENV_NAME/.env (copia .env.example y llénalo)" >&2; exit 1; }

exec docker compose --project-directory "$DIR" --env-file "$ENV_FILE" \
  -f "$DIR/base.yml" -f "$DIR/$ENV_NAME/docker-compose.yml" "$@"
