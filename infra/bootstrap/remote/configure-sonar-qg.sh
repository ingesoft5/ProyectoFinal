#!/usr/bin/env bash
# Corre DENTRO de cg-tools. Crea el quality gate "CircleGuard" y lo deja por defecto. Idempotente.
# Se evalúa sobre el código nuevo de cada análisis; el pipeline falla si no pasa.
# Uso: bash configure-sonar-qg.sh <clave-admin> <puerto>
set -euo pipefail
SQ_PASS="${1:?}" PORT="${2:?}"
api() { curl -fsS -u "admin:$SQ_PASS" "localhost:$PORT/api/$1" "${@:2}"; }

if ! api "qualitygates/show?name=CircleGuard" >/dev/null 2>&1; then
  api qualitygates/create -X POST --data-urlencode name=CircleGuard >/dev/null
  # métrica  operador  umbral   (cobertura 60 % = meta de la rúbrica para los servicios núcleo)
  while read -r metric op value; do
    api qualitygates/create_condition -X POST --data-urlencode gateName=CircleGuard \
      --data-urlencode metric="$metric" --data-urlencode op="$op" --data-urlencode error="$value" >/dev/null
  done <<'CONDS'
new_coverage LT 60
new_reliability_rating GT 1
new_security_rating GT 1
new_maintainability_rating GT 1
new_duplicated_lines_density GT 3
new_security_hotspots_reviewed LT 100
CONDS
  echo "[sonar] quality gate CircleGuard creado"
fi
api qualitygates/set_as_default -X POST --data-urlencode name=CircleGuard
echo "[sonar] quality gate CircleGuard por defecto"
