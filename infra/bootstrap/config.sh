# shellcheck shell=bash
# shellcheck disable=SC2034  # variables usadas por los scripts que hacen source de este archivo
# Configuración compartida por los scripts de bootstrap. Cada valor se puede
# sobreescribir con una variable de entorno del mismo nombre.

PROJECT="${PROJECT:-circleguard}"
AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_REGION AWS_DEFAULT_REGION="$AWS_REGION"

# Una VM por rol. dev, stage y prod quedan aislados: VM, security group e IP propios.
ROLES=(tools dev stage prod)
declare -A INSTANCE_TYPE=(
  [tools]="${TOOLS_INSTANCE_TYPE:-t3.xlarge}"  # 4 vCPU / 16 GB: Jenkins, SonarQube, Nexus
  [dev]="${ENV_INSTANCE_TYPE:-t3.large}"       # 2 vCPU / 8 GB: 5 servicios núcleo + middleware + web
  [stage]="${ENV_INSTANCE_TYPE:-t3.large}"
  [prod]="${ENV_INSTANCE_TYPE:-t3.large}"
)
declare -A DISK_GB=([tools]=60 [dev]=30 [stage]=30 [prod]=30)

# Ubuntu 24.04 LTS oficial de Canonical, resuelto por SSM (siempre la AMI vigente).
AMI_PARAM="/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
SSH_USER="ubuntu"

# Puertos expuestos
JENKINS_PORT=8080
SONAR_PORT=9000
NEXUS_PORT=8081
REGISTRY_PORT=8082   # repositorio Docker "hosted" de Nexus
WEB_PORT=80          # cliente web de cada ambiente

GITHUB_REPO="${GITHUB_REPO:-ingesoft5/circle-guard-finalproject-A00405392-A00405468}"

BOOTSTRAP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$BOOTSTRAP_DIR/../.." && pwd)"
STATE_DIR="$BOOTSTRAP_DIR/.state"          # en .gitignore: IPs, llaves y secretos generados
KEY_NAME="${PROJECT}-key"
KEY_FILE="$STATE_DIR/${KEY_NAME}.pem"
HOSTS_FILE="$STATE_DIR/hosts.env"
SECRETS_FILE="$STATE_DIR/secrets.env"
