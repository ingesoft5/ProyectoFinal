#!/usr/bin/env bash
# Un solo comando para reconstruir toda la infraestructura de la Parte 1 desde cero.
# Se puede correr las veces que sea: la segunda vez no cambia nada.
#
#   GITHUB_TOKEN=... DISCORD_WEBHOOK_URL=... BUDGET_EMAIL=... ./infra/bootstrap/up.sh
#
# (los tres valores solo hacen falta la primera vez; luego quedan en infra/bootstrap/.state/)
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/config.sh"
source "$DIR/lib.sh"
LOG_TAG=up

if [[ -n "${BUDGET_EMAIL:-}" ]]; then "$DIR/bootstrap-budget.sh"; else warn "Sin BUDGET_EMAIL: se omite el presupuesto (ya creado antes)"; fi
# Sin argumentos: todo. Con argumentos: solo esas VMs, p. ej. `up.sh tools` para probar el pipeline.
roles=("$@"); [[ ${#roles[@]} -gt 0 ]] || roles=("${ROLES[@]}")
[[ " ${roles[*]} " == *" tools "* ]] || die "tools siempre debe estar (Jenkins configura y despliega)"
ONLY_ROLES="${roles[*]}" "$DIR/bootstrap-cloud.sh"
"$DIR/bootstrap-tools.sh"
for env in "${roles[@]}"; do [[ "$env" == tools ]] || "$DIR/bootstrap-env.sh" "$env"; done

log "Infraestructura lista:"
log "  Jenkins   http://$(host_ip tools):$JENKINS_PORT"
log "  SonarQube http://$(host_ip tools):$SONAR_PORT"
log "  Nexus     http://$(host_ip tools):$NEXUS_PORT"
for env in "${roles[@]}"; do [[ "$env" == tools ]] || log "  $env  http://$(host_ip "$env")"; done
