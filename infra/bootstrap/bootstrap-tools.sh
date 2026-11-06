#!/usr/bin/env bash
# Instala y configura en cg-tools: Nexus, SonarQube y Jenkins (JCasC), y el webhook de GitHub.
# Todo por API y archivos versionados: no hay pasos manuales. Idempotente.
# La primera vez necesita GITHUB_TOKEN (PAT classic con scope repo) en .state/secrets.env.
# DISCORD_WEBHOOK_URL es opcional al inicio.
set -euo pipefail
source "$(dirname "$0")/config.sh"
source "$(dirname "$0")/lib.sh"
LOG_TAG=tools
require ssh rsync gh jq ssh-keygen

[[ -f "$HOSTS_FILE" ]] || die "Corre primero bootstrap-cloud.sh"
TOOLS_PUB="$(host_ip tools)"; TOOLS_PRIV="$(host_priv tools)"
REGISTRY="$TOOLS_PRIV:$REGISTRY_PORT"
REMOTE_DIR="/opt/circleguard-tools"

# --- Secretos (se generan una sola vez y quedan en .state/secrets.env) ---------
for s in JENKINS_ADMIN_PASSWORD JENKINS_JMROJAS06_PASSWORD JENKINS_PIERRECUEVAS_PASSWORD JENKINS_DOCENTE_PASSWORD \
         SONAR_DB_PASSWORD NEXUS_ADMIN_PASSWORD NEXUS_CI_PASSWORD; do
  ensure_secret "$s"
done
# SonarQube 26 exige mayúscula, minúscula, número y carácter especial.
ensure_secret SONAR_ADMIN_PASSWORD 20 strong
secret_from_env GITHUB_TOKEN
secret_from_env DISCORD_WEBHOOK_URL optional   # E1.5: aviso de fallos; se puede activar después
secret_from_env WHATSAPP_RECIPIENTS optional   # "+57XXXXXXXXXX:apikey,+57...:apikey" (CallMeBot)
DEPLOY_KEY="$STATE_DIR/deploy_key"
[[ -f "$DEPLOY_KEY" ]] || ssh-keygen -q -t ed25519 -N "" -C "jenkins-deploy@$PROJECT" -f "$DEPLOY_KEY"
sec() { state_get "$SECRETS_FILE" "$1"; }

# --- Host ------------------------------------------------------------------------
wait_for_ssh tools
push tools "$BOOTSTRAP_DIR/remote/" /tmp/cg-remote/
remote tools "sudo bash /tmp/cg-remote/host-common.sh $REGISTRY"
reconnect tools   # el usuario ubuntu acaba de entrar al grupo docker
remote tools "sudo mkdir -p $REMOTE_DIR/secrets && sudo chown -R $SSH_USER: $REMOTE_DIR"
# --delete no toca lo excluido: .env y secrets/ sobreviven a cada sincronización.
rsync -az --delete -e "ssh ${ssh_opts[*]} -i $KEY_FILE" --exclude secrets --exclude .env \
  "$REPO_ROOT/infra/tools/" "$SSH_USER@$TOOLS_PUB:$REMOTE_DIR/"
rsync -az --chmod=F600 -e "ssh ${ssh_opts[*]} -i $KEY_FILE" "$DEPLOY_KEY" "$SSH_USER@$TOOLS_PUB:$REMOTE_DIR/secrets/deploy_key"
remote tools "chmod 644 $REMOTE_DIR/secrets/deploy_key"   # lo lee el usuario jenkins (uid 1000) del contenedor

write_env() {   # .env de las herramientas: se reescribe completo en cada ejecución
  local docker_gid; docker_gid="$(remote tools "getent group docker | cut -d: -f3")"
  {
    echo "DOCKER_GID=$docker_gid"
    echo "JENKINS_URL=http://$TOOLS_PUB:$JENKINS_PORT/"
    echo "REGISTRY=$REGISTRY"
    for env in dev stage prod; do
      echo "${env^^}_HOST=$(host_priv "$env")"
      echo "${env^^}_URL=http://$(host_ip "$env")"
    done
    echo "GITHUB_REPO=$GITHUB_REPO"
    echo "GITHUB_REPO_OWNER=${GITHUB_REPO%%/*}"
    echo "GITHUB_REPO_NAME=${GITHUB_REPO##*/}"
    echo "GITHUB_USER=$(gh api user --jq .login)"
    for s in JENKINS_ADMIN_PASSWORD JENKINS_JMROJAS06_PASSWORD JENKINS_PIERRECUEVAS_PASSWORD JENKINS_DOCENTE_PASSWORD \
             SONAR_DB_PASSWORD NEXUS_CI_PASSWORD GITHUB_TOKEN DISCORD_WEBHOOK_URL WHATSAPP_RECIPIENTS; do
      echo "$s=$(sec "$s")"
    done
    echo "SONAR_TOKEN=$(sec SONAR_TOKEN)"
  } | remote tools "umask 077 && cat > $REMOTE_DIR/.env"
}
write_env
remote tools "cd $REMOTE_DIR && docker compose up -d sonar-db sonarqube nexus"

# --- Nexus -----------------------------------------------------------------------
log "Configurando Nexus"
wait_for_http tools "http://localhost:$NEXUS_PORT/service/rest/v1/status" 200 60
NX_PASS="$(sec NEXUS_ADMIN_PASSWORD)"
remote tools "bash /tmp/cg-remote/configure-nexus.sh '$NX_PASS' '$(sec NEXUS_CI_PASSWORD)' $REGISTRY_PORT"

# --- SonarQube ---------------------------------------------------------------------
log "Configurando SonarQube"
wait_for_http tools "http://localhost:$SONAR_PORT/api/system/status" 200 60
remote tools "for i in \$(seq 1 60); do curl -s localhost:$SONAR_PORT/api/system/status | grep -q '\"UP\"' && exit 0; sleep 5; done; exit 1" \
  || die "SonarQube no llegó a UP"
SQ_PASS="$(sec SONAR_ADMIN_PASSWORD)"
if remote tools "curl -fs -u admin:admin localhost:$SONAR_PORT/api/authentication/validate | grep -q '\"valid\":true'"; then
  remote tools "curl -fsS -u admin:admin -X POST localhost:$SONAR_PORT/api/users/change_password \
    --data-urlencode login=admin --data-urlencode previousPassword=admin --data-urlencode password='$SQ_PASS'"
  log "Contraseña de admin de SonarQube cambiada"
fi
if [[ -z "$(sec SONAR_TOKEN)" ]]; then
  token="$(remote tools "curl -fsS -u admin:'$SQ_PASS' -X POST localhost:$SONAR_PORT/api/user_tokens/generate \
    --data-urlencode name=jenkins-$(date +%s) --data-urlencode type=GLOBAL_ANALYSIS_TOKEN" | jq -r .token)"
  state_set "$SECRETS_FILE" SONAR_TOKEN "$token"
  log "Token de análisis para Jenkins creado"
fi
# Webhook de SonarQube -> Jenkins (lo usa waitForQualityGate).
if ! remote tools "curl -fsS -u admin:'$SQ_PASS' localhost:$SONAR_PORT/api/webhooks/list" | jq -e '.webhooks[]|select(.name=="jenkins")' >/dev/null; then
  remote tools "curl -fsS -u admin:'$SQ_PASS' -X POST localhost:$SONAR_PORT/api/webhooks/create \
    --data-urlencode name=jenkins --data-urlencode url=http://jenkins:8080/sonarqube-webhook/" >/dev/null
  log "Webhook SonarQube -> Jenkins creado"
fi

# --- Jenkins -------------------------------------------------------------------------
log "Levantando Jenkins (JCasC)"
write_env   # ahora incluye SONAR_TOKEN
remote tools "cd $REMOTE_DIR && docker compose up -d --build jenkins"
wait_for_http tools "http://localhost:$JENKINS_PORT/login" 200 60

# --- Webhook de GitHub -> Jenkins -----------------------------------------------------
HOOK_URL="http://$TOOLS_PUB:$JENKINS_PORT/github-webhook/"
if gh api "repos/$GITHUB_REPO/hooks" --jq '.[].config.url' | grep -x "$HOOK_URL" >/dev/null; then
  log "Webhook de GitHub ya existe"
else
  gh api "repos/$GITHUB_REPO/hooks" -f name=web -F active=true -f 'events[]=push' -f 'events[]=pull_request' \
    -f "config[url]=$HOOK_URL" -f 'config[content_type]=json' >/dev/null
  log "Webhook de GitHub creado: $HOOK_URL"
fi

log "Listo → Jenkins http://$TOOLS_PUB:$JENKINS_PORT · SonarQube http://$TOOLS_PUB:$SONAR_PORT · Nexus http://$TOOLS_PUB:$NEXUS_PORT"
log "Contraseñas en $SECRETS_FILE (fuera del repo)"
