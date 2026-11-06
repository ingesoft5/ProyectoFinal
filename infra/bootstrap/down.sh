#!/usr/bin/env bash
# Ahorro de costos: apaga las VMs (por defecto) o destruye todo (--destroy).
#   ./infra/bootstrap/down.sh            # detiene las 4 VMs; up.sh las vuelve a encender
#   ./infra/bootstrap/down.sh dev stage  # detiene solo esas
#   ./infra/bootstrap/down.sh --destroy  # termina VMs y libera IPs, security groups y key pair
set -euo pipefail
source "$(dirname "$0")/config.sh"
source "$(dirname "$0")/lib.sh"
LOG_TAG=down
require aws

ids_for() {
  aws ec2 describe-instances --filters "Name=tag:Project,Values=$PROJECT" "Name=tag:Role,Values=$1" \
    "Name=instance-state-name,Values=pending,running,stopping,stopped" --query 'Reservations[].Instances[].InstanceId' --output text
}

if [[ "${1:-}" != "--destroy" ]]; then
  roles=("$@"); [[ ${#roles[@]} -gt 0 ]] || roles=("${ROLES[@]}")
  for role in "${roles[@]}"; do
    ids="$(ids_for "$role")"
    [[ -z "$ids" ]] && { log "$role: no existe"; continue; }
    # shellcheck disable=SC2086
    aws ec2 stop-instances --instance-ids $ids >/dev/null && log "$role detenida ($ids)"
  done
  exit 0
fi

read -rp "Esto TERMINA las VMs y borra sus discos. Escribe 'destruir' para seguir: " ok
[[ "$ok" == "destruir" ]] || die "Cancelado"
all="$(for r in "${ROLES[@]}"; do ids_for "$r"; done | xargs)"
if [[ -n "$all" ]]; then
  # shellcheck disable=SC2086
  aws ec2 terminate-instances --instance-ids $all >/dev/null && aws ec2 wait instance-terminated --instance-ids $all
  log "VMs terminadas"
fi
for alloc in $(aws ec2 describe-addresses --filters "Name=tag:Project,Values=$PROJECT" --query 'Addresses[].AllocationId' --output text); do
  aws ec2 release-address --allocation-id "$alloc" && log "IP elástica $alloc liberada"
done
for sg in $(aws ec2 describe-security-groups --filters "Name=tag:Project,Values=$PROJECT" --query 'SecurityGroups[].GroupId' --output text); do
  aws ec2 revoke-security-group-ingress --group-id "$sg" \
    --ip-permissions "$(aws ec2 describe-security-groups --group-ids "$sg" --query 'SecurityGroups[0].IpPermissions' --output json)" >/dev/null 2>&1 || true
done
for sg in $(aws ec2 describe-security-groups --filters "Name=tag:Project,Values=$PROJECT" --query 'SecurityGroups[].GroupId' --output text); do
  aws ec2 delete-security-group --group-id "$sg" && log "Security group $sg borrado"
done
aws ec2 delete-key-pair --key-name "$KEY_NAME" && rm -f "$KEY_FILE" "$HOSTS_FILE" && log "Key pair borrado"
log "Infraestructura destruida. Los secretos siguen en $SECRETS_FILE por si se reconstruye."
