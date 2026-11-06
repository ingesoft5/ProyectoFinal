#!/usr/bin/env bash
# Toma una foto del avance de un sprint desde GitHub Projects y regenera su burndown.
# Uso: ./docs/agil/metricas/burndown.sh "Sprint 1" 2026-11-05 2026-11-08
# Se corre una vez al día (en la daily). Si ya hay foto de hoy, la reemplaza.
set -euo pipefail

SPRINT="${1:?Nombre del sprint, p. ej. \"Sprint 1\"}"
START="${2:?Fecha de inicio AAAA-MM-DD}"
END="${3:?Fecha de fin AAAA-MM-DD}"
OWNER="${PROJECT_OWNER:-ingesoft5}"
NUMBER="${PROJECT_NUMBER:-8}"

DIR="$(cd "$(dirname "$0")" && pwd)"
SLUG="$(tr '[:upper:] ' '[:lower:]-' <<<"$SPRINT")"
CSV="$DIR/$SLUG.csv"
MD="$DIR/$SLUG-burndown.md"
TODAY="$(date +%F)"

items="$(gh project item-list "$NUMBER" --owner "$OWNER" --limit 200 --format json)"
read -r total remaining done_count open_count < <(jq -r --arg s "$SPRINT" '
  [.items[] | select(.sprint == $s and .content.type == "Issue")] as $it
  | ($it | map(."story Points" // 0) | add // 0) as $total
  | ($it | map(select(.status != "Done")) | map(."story Points" // 0) | add // 0) as $rem
  | "\($total) \($rem) \($it | map(select(.status == "Done")) | length) \($it | map(select(.status != "Done")) | length)"
' <<<"$items")

[[ -f "$CSV" ]] || echo "fecha,puntos_totales,puntos_pendientes,historias_hechas,historias_abiertas" >"$CSV"
grep -v "^$TODAY," "$CSV" >"$CSV.tmp" && mv "$CSV.tmp" "$CSV"
echo "$TODAY,$total,$remaining,$done_count,$open_count" >>"$CSV"
{ head -1 "$CSV"; tail -n +2 "$CSV" | sort; } >"$CSV.tmp" && mv "$CSV.tmp" "$CSV"
echo "[$SPRINT] $TODAY: $remaining de $total puntos pendientes ($done_count hechas, $open_count abiertas)"

# Burndown en Mermaid (GitHub lo dibuja): línea ideal vs. real.
days=()
d="$START"
while [[ "$d" < "$END" || "$d" == "$END" ]]; do days+=("$d"); d="$(date -d "$d +1 day" +%F)"; done
n=${#days[@]}
labels="" ideal="" real=""
for i in "${!days[@]}"; do
  day="${days[$i]}"
  labels+="\"${day:5}\", "
  ideal+="$(awk -v t="$total" -v i="$i" -v n="$n" 'BEGIN{printf "%.1f", t - t*i/(n-1)}'), "
  val="$(awk -F, -v d="$day" '$1==d{print $3}' "$CSV")"
  real+="${val:-$(awk -F, -v d="$day" 'NR>1 && $1<=d{v=$3} END{print v}' "$CSV")}, "
done
# Los días futuros no tienen dato real: se cortan para que la línea no siga plana.
last_real_idx=-1
for i in "${!days[@]}"; do [[ "${days[$i]}" > "$TODAY" ]] || last_real_idx=$i; done
real="$(tr -d ' ' <<<"$real" | cut -d, -f1-$((last_real_idx + 1)) | sed 's/,/, /g')"

cat >"$MD" <<EOF
# Burndown — $SPRINT ($START → $END)

Generado con \`docs/agil/metricas/burndown.sh\` a partir del tablero de GitHub Projects. Datos en [\`$SLUG.csv\`]($SLUG.csv).

\`\`\`mermaid
xychart-beta
    title "$SPRINT: puntos pendientes"
    x-axis [${labels%, }]
    y-axis "Story points" 0 --> $total
    line [${ideal%, }]
    line [${real}]
\`\`\`

Línea de arriba al inicio: **ideal** (baja lineal hasta 0). Segunda línea: **real** (puntos de historias que no están en *Done*).

| Fecha | Pendientes | Hechas | Abiertas |
|---|---|---|---|
$(tail -n +2 "$CSV" | awk -F, '{printf "| %s | %s / %s | %s | %s |\n", $1, $3, $2, $4, $5}')
EOF
echo "Actualizado: $MD"
