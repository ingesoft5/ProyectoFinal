#!/usr/bin/env bash
# Crea (o actualiza) el presupuesto mensual de AWS con avisos por correo.
# Idempotente: correrlo varias veces deja el mismo presupuesto y las mismas alertas.
#
# Uso:  BUDGET_EMAIL=correo@ejemplo.com ./infra/bootstrap/bootstrap-budget.sh
# Opcional: BUDGET_LIMIT_USD (default 50), BUDGET_NAME (default circleguard-mensual)
set -euo pipefail

BUDGET_NAME="${BUDGET_NAME:-circleguard-mensual}"
BUDGET_LIMIT_USD="${BUDGET_LIMIT_USD:-50}"
: "${BUDGET_EMAIL:?Define BUDGET_EMAIL con el correo que recibe las alertas}"

log() { printf '[budget] %s\n' "$*"; }

command -v aws >/dev/null || { log "Falta AWS CLI"; exit 1; }
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
log "Cuenta ${ACCOUNT_ID}, presupuesto '${BUDGET_NAME}' de USD ${BUDGET_LIMIT_USD}/mes"

budget_json() {
  cat <<EOF
{
  "BudgetName": "${BUDGET_NAME}",
  "BudgetLimit": {"Amount": "${BUDGET_LIMIT_USD}", "Unit": "USD"},
  "TimeUnit": "MONTHLY",
  "BudgetType": "COST",
  "CostTypes": {"IncludeCredit": false, "IncludeRefund": false}
}
EOF
}

# Alertas: gasto real al 50 % y al 80 %, y pronóstico del mes al 100 %.
ALERTS=("ACTUAL:50" "ACTUAL:80" "FORECASTED:100")

if aws budgets describe-budget --account-id "$ACCOUNT_ID" --budget-name "$BUDGET_NAME" >/dev/null 2>&1; then
  log "El presupuesto ya existe: se actualiza el límite"
  aws budgets update-budget --account-id "$ACCOUNT_ID" --new-budget "$(budget_json)"
else
  log "Creando presupuesto"
  aws budgets create-budget --account-id "$ACCOUNT_ID" --budget "$(budget_json)"
fi

existing="$(aws budgets describe-notifications-for-budget --account-id "$ACCOUNT_ID" \
  --budget-name "$BUDGET_NAME" \
  --query 'Notifications[].[NotificationType,Threshold]' --output text)"

for alert in "${ALERTS[@]}"; do
  type="${alert%%:*}"; threshold="${alert##*:}"
  if grep -qE "^${type}[[:space:]]+${threshold}(\.0)?$" <<<"$existing"; then
    log "Alerta ${type} ${threshold}% ya existe"
    continue
  fi
  log "Creando alerta ${type} ${threshold}%"
  aws budgets create-notification --account-id "$ACCOUNT_ID" --budget-name "$BUDGET_NAME" \
    --notification "NotificationType=${type},ComparisonOperator=GREATER_THAN,Threshold=${threshold},ThresholdType=PERCENTAGE" \
    --subscribers "SubscriptionType=EMAIL,Address=${BUDGET_EMAIL}"
done

log "Listo. Estado actual:"
aws budgets describe-notifications-for-budget --account-id "$ACCOUNT_ID" --budget-name "$BUDGET_NAME" \
  --query 'Notifications[].{Tipo:NotificationType,Umbral:Threshold}' --output table
