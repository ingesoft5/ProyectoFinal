#!/usr/bin/env bash
# Envía un aviso del pipeline por WhatsApp (CallMeBot) y Discord. Lo usa notifyTeam.groovy,
# y se puede probar a mano:
#   WHATSAPP_RECIPIENTS="+573001234567:123456" ./notify.sh FAILURE "circleguard #12" "Falló Unit tests" "http://jenkins/..."
#
# Variables (las inyecta Jenkins desde credenciales; si faltan o dicen "pendiente", ese canal se omite):
#   WHATSAPP_RECIPIENTS  lista "telefono:apikey" separada por comas (teléfono con indicativo, p. ej. +57...)
#   DISCORD_WEBHOOK_URL  URL del webhook del canal de Discord
#
# Nunca falla: un aviso que no sale no debe tumbar el pipeline.
set -uo pipefail

STATUS="${1:?Estado: SUCCESS, FAILURE, UNSTABLE, ABORTED, APPROVAL, INFO}"
TITLE="${2:?Título, p. ej. 'circleguard/main #12'}"
DETAIL="${3:-}"
LINK="${4:-}"

case "$STATUS" in
  SUCCESS)  icon="✅"; color=3066993 ;;
  FAILURE)  icon="❌"; color=15158332 ;;
  UNSTABLE) icon="⚠️"; color=15844367 ;;
  ABORTED)  icon="⏹️"; color=9807270 ;;
  APPROVAL) icon="🟡"; color=16776960 ;;
  *)        icon="ℹ️"; color=3447003 ;;
esac

configured() { [[ -n "${1:-}" && "$1" != "pendiente" ]]; }
sent=0

# --- WhatsApp vía CallMeBot (uso personal: cada integrante activa su propio número) ---
if configured "${WHATSAPP_RECIPIENTS:-}"; then
  text="$icon *CircleGuard · $STATUS*"$'\n'"$TITLE"
  [[ -n "$DETAIL" ]] && text+=$'\n'"$DETAIL"
  [[ -n "$LINK" ]] && text+=$'\n'"$LINK"
  IFS=',' read -ra recipients <<<"$WHATSAPP_RECIPIENTS"
  for r in "${recipients[@]}"; do
    phone="${r%%:*}"; apikey="${r#*:}"
    code="$(curl -s -o /tmp/callmebot.$$ -w '%{http_code}' --max-time 20 -G https://api.callmebot.com/whatsapp.php \
      --data-urlencode "phone=$phone" --data-urlencode "text=$text" --data-urlencode "apikey=$apikey")"
    # CallMeBot responde 200 o 203 con "Message queued" cuando acepta el envío.
    if [[ "$code" == 20[03] ]] && grep -qi "queued\|sent" /tmp/callmebot.$$ && ! grep -qi "error\|invalid\|not activated" /tmp/callmebot.$$; then
      echo "[notify] WhatsApp enviado a ${phone:0:4}…${phone: -2}"; sent=$((sent + 1))
    else
      echo "[notify] WhatsApp a ${phone:0:4}…${phone: -2} falló (HTTP $code): $(sed 's/<[^>]*>//g' /tmp/callmebot.$$ | tr -s ' \n' ' ' | tail -c 220)"
    fi
    rm -f /tmp/callmebot.$$
    sleep 2   # CallMeBot es gratuito: se espacian los envíos
  done
fi

# --- Discord (webhook del canal) ---
if configured "${DISCORD_WEBHOOK_URL:-}"; then
  payload="$(jq -n --arg t "$icon $STATUS · $TITLE" --arg d "$DETAIL" --arg u "$LINK" --argjson c "$color" \
    '{username:"CircleGuard CI", embeds:[{title:$t, description:$d, url:(if $u=="" then null else $u end), color:$c}]}')"
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 -H 'Content-Type: application/json' -d "$payload" "$DISCORD_WEBHOOK_URL")"
  if [[ "$code" == 204 || "$code" == 200 ]]; then echo "[notify] Discord enviado"; sent=$((sent + 1))
  else echo "[notify] Discord falló (HTTP $code)"; fi
fi

[[ $sent -gt 0 ]] || echo "[notify] Ningún canal configurado o disponible: aviso omitido"
exit 0
