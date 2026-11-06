#!/usr/bin/env bash
# Corre DENTRO de cg-tools. Configura Nexus por su API REST. Idempotente.
# Uso: bash configure-nexus.sh <clave-admin> <clave-ci> <puerto-registro>
set -euo pipefail
NX_PASS="${1:?}" CI_PASS="${2:?}" REG_PORT="${3:?}"
API=http://localhost:8081/service/rest
cd /opt/circleguard-tools
# 1) Contraseña inicial de admin -> la generada (solo la primera vez).
if docker compose exec -T nexus test -f /nexus-data/admin.password </dev/null; then
  init="$(docker compose exec -T nexus cat /nexus-data/admin.password </dev/null)"
  curl -fsS -u "admin:$init" -X PUT -H 'Content-Type: text/plain' --data "$NX_PASS" "$API/v1/security/users/admin/change-password"
  docker compose exec -T nexus rm -f /nexus-data/admin.password </dev/null
  echo "[nexus] contraseña de admin cambiada"
fi
c() { curl -fsS -u "admin:$NX_PASS" -H 'Content-Type: application/json' "$@"; }
# 2) EULA de la edición Community (si la versión lo exige).
if eula="$(c "$API/v1/system/eula" 2>/dev/null)" && [[ "$(jq -r .accepted <<<"$eula")" == "false" ]]; then
  c -X POST "$API/v1/system/eula" -d "$(jq '.accepted=true' <<<"$eula")" && echo "[nexus] EULA aceptada"
fi
# 3) Sin acceso anónimo; realm de tokens Docker activo.
c -X PUT "$API/v1/security/anonymous" -d '{"enabled":false,"userId":"anonymous","realmName":"NexusAuthorizingRealm"}' >/dev/null
c -X PUT "$API/v1/security/realms/active" -d '["NexusAuthenticatingRealm","DockerToken"]'
# 4) Repositorio Docker "circleguard": allow_once = un tag publicado no se puede sobreescribir (inmutable).
if ! c "$API/v1/repositories/docker/hosted/circleguard" >/dev/null 2>&1; then
  c -X POST "$API/v1/repositories/docker/hosted" -d "{\"name\":\"circleguard\",\"online\":true,
    \"storage\":{\"blobStoreName\":\"default\",\"strictContentTypeValidation\":true,\"writePolicy\":\"allow_once\"},
    \"docker\":{\"v1Enabled\":false,\"forceBasicAuth\":true,\"httpPort\":$REG_PORT}}"
  echo "[nexus] repositorio docker 'circleguard' creado en el puerto $REG_PORT"
fi
# 5) Rol y usuario de CI con permisos solo sobre ese repositorio.
c "$API/v1/security/roles/ci-docker" >/dev/null 2>&1 || c -X POST "$API/v1/security/roles" -d '{"id":"ci-docker","name":"ci-docker",
  "description":"Publicar y descargar imagenes de circleguard","privileges":["nx-repository-view-docker-circleguard-*"],"roles":[]}'
if [[ "$(c "$API/v1/security/users?userId=ci" | jq length)" == "0" ]]; then
  c -X POST "$API/v1/security/users" -d "{\"userId\":\"ci\",\"firstName\":\"CI\",\"lastName\":\"Jenkins\",
    \"emailAddress\":\"ci@circleguard.local\",\"password\":\"$CI_PASS\",\"status\":\"active\",\"roles\":[\"ci-docker\"]}" >/dev/null
  echo "[nexus] usuario ci creado"
fi
echo "[nexus] configuración lista"
