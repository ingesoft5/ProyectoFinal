#!/usr/bin/env bash
# Deja lista la VM de un ambiente (dev, stage o prod) para que Jenkins despliegue en ella.
# Uso: ./infra/bootstrap/bootstrap-env.sh dev
set -euo pipefail
source "$(dirname "$0")/config.sh"
source "$(dirname "$0")/lib.sh"
ENV_NAME="${1:?Ambiente: dev, stage o prod}"
[[ " dev stage prod " == *" $ENV_NAME "* ]] || die "Ambiente inválido: $ENV_NAME"
LOG_TAG="env:$ENV_NAME"
require ssh rsync

[[ -f "$STATE_DIR/deploy_key.pub" ]] || die "Corre primero bootstrap-tools.sh (genera la llave de despliegue)"
REGISTRY="$(host_priv tools):$REGISTRY_PORT"

wait_for_ssh "$ENV_NAME"
push "$ENV_NAME" "$BOOTSTRAP_DIR/remote/" /tmp/cg-remote/
remote "$ENV_NAME" "sudo bash /tmp/cg-remote/host-common.sh $REGISTRY"
reconnect "$ENV_NAME"   # el usuario ubuntu acaba de entrar al grupo docker

# Llave de despliegue de Jenkins en authorized_keys (una sola vez).
pub="$(cat "$STATE_DIR/deploy_key.pub")"
remote "$ENV_NAME" "grep -qxF '$pub' ~/.ssh/authorized_keys || echo '$pub' >> ~/.ssh/authorized_keys"

# Carpeta del despliegue y nombre del ambiente (lo usa el compose de deploy/compose/<env>).
remote "$ENV_NAME" "sudo mkdir -p /opt/circleguard && sudo chown $SSH_USER: /opt/circleguard && echo $ENV_NAME > /opt/circleguard/ENVIRONMENT"

# Credenciales para descargar imágenes de Nexus (docker login es idempotente).
state_get "$SECRETS_FILE" NEXUS_CI_PASSWORD \
  | remote "$ENV_NAME" "docker login --username ci --password-stdin $REGISTRY >/dev/null && echo '[env] docker login en $REGISTRY OK'"

log "Ambiente $ENV_NAME listo en http://$(host_ip "$ENV_NAME")"
