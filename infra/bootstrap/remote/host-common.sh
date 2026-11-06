#!/usr/bin/env bash
# Corre DENTRO de cada VM (como root). Instala Docker y deja el host listo.
# Idempotente: cada paso revisa el estado antes de cambiarlo.
# Uso: sudo bash host-common.sh <registro-inseguro host:puerto>
set -euo pipefail
REGISTRY="${1:?registro Docker de Nexus, p. ej. 10.0.0.5:8082}"
log() { printf '[host %s] %s\n' "$(hostname)" "$*"; }

if ! command -v docker >/dev/null; then
  log "Instalando Docker Engine"
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  # shellcheck disable=SC1091
  . /etc/os-release
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $VERSION_CODENAME stable" \
    >/etc/apt/sources.list.d/docker.list
  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin rsync jq >/dev/null
fi
id -nG ubuntu | grep -qw docker || usermod -aG docker ubuntu

# Nexus sirve el registro por HTTP dentro de la VPC: se declara como registro inseguro.
desired="$(jq -n --arg r "$REGISTRY" '{"insecure-registries":[$r],"log-driver":"json-file","log-opts":{"max-size":"20m","max-file":"3"}}')"
if [[ "$(cat /etc/docker/daemon.json 2>/dev/null)" != "$desired" ]]; then
  log "Configurando /etc/docker/daemon.json (registro $REGISTRY)"
  echo "$desired" >/etc/docker/daemon.json
  systemctl restart docker
fi

# SonarQube (Elasticsearch) exige vm.max_map_count alto; en las demás VMs no estorba.
if [[ "$(sysctl -n vm.max_map_count)" -lt 524288 ]]; then
  echo "vm.max_map_count=524288" >/etc/sysctl.d/99-circleguard.conf
  sysctl -q --system
fi

# Swap de 4 GB como colchón de memoria para los contenedores Java.
if ! swapon --show | grep -q /swapfile; then
  log "Creando swap de 4 GB"
  fallocate -l 4G /swapfile && chmod 600 /swapfile && mkswap -q /swapfile && swapon /swapfile
  grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >>/etc/fstab
fi

log "Docker $(docker --version | awk '{print $3}' | tr -d ,) listo"
