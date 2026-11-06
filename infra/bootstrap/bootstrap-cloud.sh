#!/usr/bin/env bash
# Crea (o reutiliza) la red y las 4 VMs en AWS: cg-tools, cg-dev, cg-stage, cg-prod.
# Idempotente: busca cada recurso por nombre/etiqueta antes de crearlo.
set -euo pipefail
source "$(dirname "$0")/config.sh"
source "$(dirname "$0")/lib.sh"
LOG_TAG=cloud
require aws jq curl

mkdir -p "$STATE_DIR"; chmod 700 "$STATE_DIR"
# Quién entra por SSH y a Nexus: la IP de quien corre el script más las de ADMIN_CIDRS
# (lista separada por comas, p. ej. ADMIN_CIDRS="203.0.113.5/32,198.51.100.7/32").
# Las reglas por CIDR de esos puertos que ya no estén en la lista se retiran (p. ej. una IP que cambió).
ADMIN_LIST=()
declare -A seen=()
IFS=',' read -ra requested <<<"${ADMIN_CIDRS:-},$(curl -s https://checkip.amazonaws.com)/32"
for cidr in "${requested[@]}"; do
  cidr="${cidr//[[:space:]]/}"
  [[ -n "$cidr" && "$cidr" != "/32" ]] || continue   # "/32" solo: checkip.amazonaws.com no respondió
  [[ "$cidr" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}/[0-9]{1,2}$ ]] || die "ADMIN_CIDRS: '$cidr' no es un CIDR IPv4 (ej. 203.0.113.5/32)"
  if [[ -z "${seen[$cidr]:-}" ]]; then seen[$cidr]=1; ADMIN_LIST+=("$cidr"); fi
done
[[ ${#ADMIN_LIST[@]} -gt 0 ]] || die "No pude saber tu IP pública: define ADMIN_CIDRS (ej. 203.0.113.5/32)"
VPC_ID="$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true --query 'Vpcs[0].VpcId' --output text)"
[[ "$VPC_ID" != "None" ]] || die "La cuenta no tiene VPC por defecto"
log "Región $AWS_REGION, VPC $VPC_ID, acceso administrativo desde ${ADMIN_LIST[*]}"

# --- Llave SSH ---------------------------------------------------------------
if aws ec2 describe-key-pairs --key-names "$KEY_NAME" >/dev/null 2>&1; then
  [[ -f "$KEY_FILE" ]] || die "El key pair $KEY_NAME existe en AWS pero falta $KEY_FILE. Bórralo en AWS o recupera la llave."
  log "Key pair $KEY_NAME ya existe"
else
  log "Creando key pair $KEY_NAME"
  aws ec2 create-key-pair --key-name "$KEY_NAME" --key-type ed25519 \
    --tag-specifications "ResourceType=key-pair,Tags=[{Key=Project,Value=$PROJECT}]" \
    --query KeyMaterial --output text >"$KEY_FILE"
  chmod 600 "$KEY_FILE"
fi

# --- Security groups (uno por rol = aislamiento entre ambientes) --------------
ensure_sg() {
  local name="$1" desc="$2" id
  id="$(aws ec2 describe-security-groups --filters "Name=group-name,Values=$name" "Name=vpc-id,Values=$VPC_ID" \
        --query 'SecurityGroups[0].GroupId' --output text)"
  if [[ "$id" == "None" ]]; then
    id="$(aws ec2 create-security-group --group-name "$name" --description "$desc" --vpc-id "$VPC_ID" \
          --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=$name},{Key=Project,Value=$PROJECT}]" \
          --query GroupId --output text)"
    log "Security group $name creado ($id)" >&2
  fi
  echo "$id"
}

# Agrega una regla de entrada; si ya existe, AWS responde Duplicate y se ignora.
allow() {
  local sg="$1" port="$2" source="$3" perm out
  if [[ "$source" == sg-* ]]; then
    perm="IpProtocol=tcp,FromPort=$port,ToPort=$port,UserIdGroupPairs=[{GroupId=$source}]"
  else
    perm="IpProtocol=tcp,FromPort=$port,ToPort=$port,IpRanges=[{CidrIp=$source}]"
  fi
  if ! out="$(aws ec2 authorize-security-group-ingress --group-id "$sg" --ip-permissions "$perm" 2>&1)"; then
    [[ "$out" == *InvalidPermission.Duplicate* ]] || die "$out"
  fi
}

# Retira de un puerto administrativo las reglas por CIDR que ya no están en ADMIN_LIST.
# Las reglas por security group (UserIdGroupPairs) no se tocan.
prune_cidrs() {
  local sg="$1" port="$2" ranges cidr
  ranges="$(aws ec2 describe-security-groups --group-ids "$sg" --output json |
    jq -r --argjson p "$port" '.SecurityGroups[0].IpPermissions[]
      | select(.IpProtocol == "tcp" and .FromPort == $p and .ToPort == $p) | .IpRanges[].CidrIp')"
  while read -r cidr; do
    [[ -n "$cidr" && " ${ADMIN_LIST[*]} " != *" $cidr "* ]] || continue
    aws ec2 revoke-security-group-ingress --group-id "$sg" --protocol tcp --port "$port" --cidr "$cidr" >/dev/null
    log "Regla $cidr retirada de $sg puerto $port (ya no está en ADMIN_CIDRS)"
  done <<<"$ranges"
}

declare -A SG
SG[tools]="$(ensure_sg "$PROJECT-tools-sg" "Jenkins, SonarQube y Nexus")"
for env in dev stage prod; do SG[$env]="$(ensure_sg "$PROJECT-$env-sg" "Ambiente $env")"; done

for cidr in "${ADMIN_LIST[@]}"; do
  allow "${SG[tools]}" 22 "$cidr"
  allow "${SG[tools]}" "$NEXUS_PORT" "$cidr"
  for env in dev stage prod; do allow "${SG[$env]}" 22 "$cidr"; done
done
allow "${SG[tools]}" "$JENKINS_PORT" 0.0.0.0/0      # webhook de GitHub y acceso del docente (con login)
allow "${SG[tools]}" "$SONAR_PORT" 0.0.0.0/0        # quality gate visible para el docente (con login)
for env in dev stage prod; do
  allow "${SG[$env]}" 22 "${SG[tools]}"               # Jenkins despliega por SSH
  allow "${SG[$env]}" "$WEB_PORT" 0.0.0.0/0           # cliente web del ambiente
  allow "${SG[tools]}" "$REGISTRY_PORT" "${SG[$env]}" # el ambiente descarga imágenes de Nexus
done
# Con las IPs nuevas ya autorizadas, se retiran las que sobran (nunca queda un momento sin acceso).
prune_cidrs "${SG[tools]}" 22
prune_cidrs "${SG[tools]}" "$NEXUS_PORT"
for env in dev stage prod; do prune_cidrs "${SG[$env]}" 22; done
log "Security groups listos"

# --- Instancias ----------------------------------------------------------------
AMI_ID="$(aws ssm get-parameter --name "$AMI_PARAM" --query Parameter.Value --output text)"

ensure_instance() {
  local role="$1" name="$PROJECT-$1" id state
  read -r id state < <(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=$name" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query 'Reservations[0].Instances[0].[InstanceId,State.Name]' --output text)
  if [[ "$id" == "None" ]]; then
    id="$(aws ec2 run-instances --image-id "$AMI_ID" --instance-type "${INSTANCE_TYPE[$role]}" \
      --key-name "$KEY_NAME" --security-group-ids "${SG[$role]}" \
      --metadata-options HttpTokens=required,HttpEndpoint=enabled \
      --block-device-mappings "DeviceName=/dev/sda1,Ebs={VolumeSize=${DISK_GB[$role]},VolumeType=gp3,DeleteOnTermination=true}" \
      --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$name},{Key=Project,Value=$PROJECT},{Key=Role,Value=$role}]" \
                           "ResourceType=volume,Tags=[{Key=Name,Value=$name},{Key=Project,Value=$PROJECT}]" \
      --query 'Instances[0].InstanceId' --output text)"
    log "Instancia $name creada ($id, ${INSTANCE_TYPE[$role]})" >&2
  elif [[ "$state" == "stopped" || "$state" == "stopping" ]]; then
    aws ec2 wait instance-stopped --instance-ids "$id"
    aws ec2 start-instances --instance-ids "$id" >/dev/null
    log "Instancia $name estaba detenida: encendida" >&2
  else
    log "Instancia $name ya existe ($id, $state)" >&2
  fi
  echo "$id"
}

# IP elástica: la dirección no cambia al apagar/encender (webhook y despliegues estables).
ensure_eip() {
  local role="$1" instance="$2" name="$PROJECT-$1-eip" alloc assoc
  read -r alloc assoc < <(aws ec2 describe-addresses --filters "Name=tag:Name,Values=$name" \
    --query 'Addresses[0].[AllocationId,InstanceId]' --output text)
  if [[ "$alloc" == "None" ]]; then
    alloc="$(aws ec2 allocate-address --domain vpc \
      --tag-specifications "ResourceType=elastic-ip,Tags=[{Key=Name,Value=$name},{Key=Project,Value=$PROJECT}]" \
      --query AllocationId --output text)"
    assoc="None"
  fi
  [[ "$assoc" == "$instance" ]] || aws ec2 associate-address --allocation-id "$alloc" --instance-id "$instance" >/dev/null
}

declare -A IID
for role in "${ROLES[@]}"; do IID[$role]="$(ensure_instance "$role")"; done
aws ec2 wait instance-running --instance-ids "${IID[@]}"
for role in "${ROLES[@]}"; do
  ensure_eip "$role" "${IID[$role]}"
  read -r pub priv < <(aws ec2 describe-instances --instance-ids "${IID[$role]}" \
    --query 'Reservations[0].Instances[0].[PublicIpAddress,PrivateIpAddress]' --output text)
  state_set "$HOSTS_FILE" "${role^^}_INSTANCE_ID" "${IID[$role]}"
  state_set "$HOSTS_FILE" "${role^^}_PUBLIC_IP" "$pub"
  state_set "$HOSTS_FILE" "${role^^}_PRIVATE_IP" "$priv"
  log "$role → $pub (privada $priv)"
done
