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
# Con "strong" agrega mayúscula, minúscula, número y carácter especial (lo exige SonarQube).
ensure_secret() {
  local key="$1" len="${2:-24}" mode="${3:-}" value
  value="$(state_get "$SECRETS_FILE" "$key")"
  if [[ -n "$value" && ( "$mode" != strong || "$value" == *[^A-Za-z0-9]* ) ]]; then return 0; fi
  value="$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c "$len" || true)"  # tr termina por SIGPIPE: es esperado
  [[ "$mode" == strong ]] && value+="Aa1-"
  state_set "$SECRETS_FILE" "$key" "$value"
}

# Copia al archivo de secretos un valor que el usuario pasa por variable de entorno.
# Con "optional", si no hay valor se guarda "pendiente" y el bootstrap sigue.
secret_from_env() {
  local key="$1" mode="${2:-required}"
  if [[ -n "${!key:-}" ]]; then state_set "$SECRETS_FILE" "$key" "${!key}"; fi
  [[ -n "$(state_get "$SECRETS_FILE" "$key")" ]] && return 0
  [[ "$mode" == optional ]] || die "Define $key en $SECRETS_FILE (o como variable de entorno) antes de correr el bootstrap"
  warn "$key sin definir: se guarda 'pendiente' y se puede completar después"
  state_set "$SECRETS_FILE" "$key" pendiente
}

host_ip()   { state_get "$HOSTS_FILE" "${1^^}_PUBLIC_IP"; }
host_priv() { state_get "$HOSTS_FILE" "${1^^}_PRIVATE_IP"; }

# Una sola conexión SSH por VM reutilizada (ControlMaster): menos conexiones y menos cortes.
ssh_opts=(-o StrictHostKeyChecking=accept-new -o UserKnownHostsFile="$STATE_DIR/known_hosts" -o ConnectTimeout=15
          -o ServerAliveInterval=15 -o LogLevel=ERROR
          -o ControlMaster=auto -o ControlPath="$HOME/.ssh/cg-%C" -o ControlPersist=120)  # ruta corta: los sockets admiten máx. 108 caracteres

# Corre un comando en la VM. Si falla la CONEXIÓN (ssh devuelve 255) reintenta; si falla el comando, no.
remote() {
  local role="$1"; shift
  local attempt rc
  for attempt in 1 2 3; do
    ssh "${ssh_opts[@]}" -i "$KEY_FILE" "$SSH_USER@$(host_ip "$role")" "$@" && return 0
    rc=$?
    [[ $rc -eq 255 && $attempt -lt 3 ]] || return "$rc"
    warn "SSH a $role se cortó (intento $attempt): reintentando en 10 s"; sleep 10
  done
}
# Cierra la conexión SSH reutilizada: la siguiente sesión toma los grupos nuevos (p. ej. docker).
reconnect() { ssh "${ssh_opts[@]}" -O exit "$SSH_USER@$(host_ip "$1")" 2>/dev/null || true; }
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
