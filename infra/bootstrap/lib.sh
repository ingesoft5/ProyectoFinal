# shellcheck shell=bash
# Funciones comunes de los scripts de bootstrap.

log()  { printf '\033[1;34m[%s]\033[0m %s\n' "${LOG_TAG:-bootstrap}" "$*"; }
warn() { printf '\033[1;33m[%s]\033[0m %s\n' "${LOG_TAG:-bootstrap}" "$*" >&2; }
die()  { printf '\033[1;31m[%s]\033[0m %s\n' "${LOG_TAG:-bootstrap}" "$*" >&2; exit 1; }

require() {
  local cmd
  for cmd in "$@"; do command -v "$cmd" >/dev/null || die "Falta el comando '$cmd'"; done
}

# Valor de una variable guardada en un archivo KEY=VALUE (hosts.env / secrets.env).
state_get() { [[ -f "$1" ]] && sed -n "s/^$2=//p" "$1" | tail -1; }

# Guarda o reemplaza KEY=VALUE en un archivo de estado.
state_set() {
  local file="$1" key="$2" value="$3"
  mkdir -p "$(dirname "$file")"; touch "$file"; chmod 600 "$file"
  grep -v "^$key=" "$file" >"$file.tmp" || true
  printf '%s=%s\n' "$key" "$value" >>"$file.tmp"
  mv "$file.tmp" "$file"
}

# Genera un secreto aleatorio solo la primera vez (idempotente).
ensure_secret() {
  local key="$1" len="${2:-24}"
  [[ -n "$(state_get "$SECRETS_FILE" "$key")" ]] && return 0
  state_set "$SECRETS_FILE" "$key" "$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c "$len")"
}

# Copia al archivo de secretos un valor que el usuario pasa por variable de entorno.
secret_from_env() {
  local key="$1"
  if [[ -n "${!key:-}" ]]; then state_set "$SECRETS_FILE" "$key" "${!key}"; fi
  [[ -n "$(state_get "$SECRETS_FILE" "$key")" ]] || die "Define $key (variable de entorno) la primera vez que corras el bootstrap"
}

host_ip()   { state_get "$HOSTS_FILE" "${1^^}_PUBLIC_IP"; }
host_priv() { state_get "$HOSTS_FILE" "${1^^}_PRIVATE_IP"; }

ssh_opts=(-o StrictHostKeyChecking=accept-new -o UserKnownHostsFile="$STATE_DIR/known_hosts" -o ConnectTimeout=10 -o LogLevel=ERROR)
remote() { local role="$1"; shift; ssh "${ssh_opts[@]}" -i "$KEY_FILE" "$SSH_USER@$(host_ip "$role")" "$@"; }
push()   { local role="$1" src="$2" dst="$3"; rsync -az --delete -e "ssh ${ssh_opts[*]} -i $KEY_FILE" "$src" "$SSH_USER@$(host_ip "$role"):$dst"; }

wait_for_ssh() {
  local role="$1"
  for _ in $(seq 1 40); do
    remote "$role" true 2>/dev/null && return 0
    sleep 5
  done
  die "No hay SSH hacia $role ($(host_ip "$role"))"
}

# Espera a que una URL responda con alguno de los códigos esperados (desde la VM).
wait_for_http() {
  local role="$1" url="$2" codes="${3:-200}" tries="${4:-60}"
  remote "$role" "for i in \$(seq 1 $tries); do c=\$(curl -s -o /dev/null -w '%{http_code}' '$url'); [[ '$codes' == *\$c* ]] && exit 0; sleep 5; done; exit 1" \
    || die "$url no respondió ($codes) en $role"
}
