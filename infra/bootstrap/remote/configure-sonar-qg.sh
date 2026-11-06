#!/usr/bin/env bash
# Corre DENTRO de cg-tools. Deja el quality gate "CircleGuard" con exactamente estas condiciones
# (sobre el código nuevo de cada análisis) y lo pone por defecto. Idempotente.
# Ojo: SonarQube 26 copia las condiciones de "Sonar way" al crear un gate; aquí se ajustan.
# Uso: bash configure-sonar-qg.sh <clave-admin> <puerto>
set -euo pipefail
SQ_PASS="${1:?}" PORT="${2:?}"
api() { curl -fsS -u "admin:$SQ_PASS" "localhost:$PORT/api/$1" "${@:2}"; }

# métrica  operador  umbral   (cobertura 60 % = meta de la rúbrica para los servicios núcleo)
DESIRED="new_coverage LT 60
new_reliability_rating GT 1
new_security_rating GT 1
new_maintainability_rating GT 1
new_duplicated_lines_density GT 3
new_security_hotspots_reviewed LT 100"

if ! api "qualitygates/show?name=CircleGuard" >/dev/null 2>&1; then
  api qualitygates/create -X POST --data-urlencode name=CircleGuard >/dev/null
  echo "[sonar] quality gate CircleGuard creado"
fi
current="$(api "qualitygates/show?name=CircleGuard" | jq -r '.conditions[]? | "\(.id) \(.metric) \(.op) \(.error)"')"

while read -r metric op value; do
  read -r id _ cur_op cur_value < <(awk -v m="$metric" '$2==m' <<<"$current") || true
  if [[ -z "${id:-}" ]]; then
    api qualitygates/create_condition -X POST --data-urlencode gateName=CircleGuard \
      --data-urlencode metric="$metric" --data-urlencode op="$op" --data-urlencode error="$value" >/dev/null
    echo "[sonar] condición agregada: $metric $op $value"
  elif [[ "$cur_op $cur_value" != "$op $value" ]]; then
    api qualitygates/update_condition -X POST --data-urlencode id="$id" \
      --data-urlencode metric="$metric" --data-urlencode op="$op" --data-urlencode error="$value" >/dev/null
    echo "[sonar] condición ajustada: $metric $cur_op $cur_value -> $op $value"
  fi
  id=""
done <<<"$DESIRED"

# Quita lo que no está en la lista (p. ej. new_violations > 0 heredado de "Sonar way").
while read -r id metric _; do
  [[ -n "$id" ]] || continue
  grep -q "^$metric " <<<"$DESIRED" && continue
  api qualitygates/delete_condition -X POST --data-urlencode id="$id"
  echo "[sonar] condición retirada: $metric"
done <<<"$current"

api qualitygates/set_as_default -X POST --data-urlencode name=CircleGuard
echo "[sonar] quality gate CircleGuard listo y por defecto"
