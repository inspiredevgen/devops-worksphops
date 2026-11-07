#!/bin/bash
# File: scripts/app/bootstrap.sh
# Purpose : First-boot setup of ONE app instance, started by the UserData of the CloudFormation
#           launch template (stack lab8-app). It:
#           1. shows its identity (IMDSv2), stack name and logical ID
#           2. installs cfn-signal (aws-cfn-bootstrap) and downloads the app files
#           3. reads both database secrets from Secrets Manager (instance role, no password anywhere)
#           4. installs the Flask app with web-setup.sh (venv, systemd service 'labapp', RDS CA)
#           5. initializes the database once with db_init.py (named lock, seed only if empty)
#           6. checks readiness and SIGNALS CloudFormation: SUCCESS -> the stack continues,
#              FAILURE (or no signal in 20 min) -> the stack rolls back
# Env     : set by the UserData: AWS_REGION, STACK_NAME, LOGICAL_ID, BASE_URL, DB_HOST,
#           MASTER_SECRET_ARN, APP_SECRET_ARN, APP_HOSTS (app subnet CIDRs), APP_VERSION
# Logs    : /var/log/cloud-init-output.log
set -Eeuo pipefail

: "${BASE_URL:?}" "${DB_HOST:?}" "${MASTER_SECRET_ARN:?}" "${APP_SECRET_ARN:?}" "${STACK_NAME:?}" "${LOGICAL_ID:?}"
APP_HOSTS="${APP_HOSTS:-10.20.11.0/24 10.20.12.0/24}"
APP_VERSION="${APP_VERSION:-1.0.0}"
export HOME="${HOME:-/root}"
WORK=/opt/lab8-src

log() { echo -e "\n==> [$(date +%T)] $*"; }

# ---------------------------------------------------------------------------
log "1/6 Identity (IMDSv2)"
TOKEN=$(curl -sf --noproxy '*' -m 2 -X PUT http://169.254.169.254/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds: 600")
md() { curl -sf --noproxy '*' -m 2 -H "X-aws-ec2-metadata-token: $TOKEN" "http://169.254.169.254/latest/meta-data/$1"; }
REGION="${AWS_REGION:-$(md placement/region)}"
STACK="$STACK_NAME"
echo "Instance $(md instance-id) in $(md placement/availability-zone) · stack ${STACK} · resource ${LOGICAL_ID}"

signal() {  # $1 = 0 (success) or 1 (failure), $2 = reason shown in the CloudFormation Events tab
  /opt/aws/bin/cfn-signal -e "$1" --stack "$STACK" --resource "$LOGICAL_ID" --region "$REGION" --reason "$2" \
    || echo "cfn-signal failed (is the instance able to reach the CloudFormation endpoint through the NAT?)"
}
on_error() {  # any failing command: tell CloudFormation now instead of waiting for the 20-minute timeout
  local rc=$? line=$1
  [[ "$BASHPID" == "$$" ]] || exit "$rc"   # inside $( ... ): let the main shell report it, once
  trap - ERR
  [[ -x /opt/aws/bin/cfn-signal ]] && signal 1 "bootstrap.sh failed at line ${line} (exit ${rc}): see /var/log/cloud-init-output.log"
  exit "$rc"
}
trap 'on_error $LINENO' ERR

# ---------------------------------------------------------------------------
log "2/6 cfn-signal + application files from ${BASE_URL}"
dnf -y -q install aws-cfn-bootstrap >/dev/null
mkdir -p "$WORK/templates" && cd "$WORK"
for f in web-setup.sh app.py requirements.txt templates/index.html db_init.py seed.sql; do
  curl -fsSL --retry 5 --retry-delay 3 --retry-all-errors -o "$f" "${BASE_URL}/${f}"
  echo "  downloaded $f"
done

# ---------------------------------------------------------------------------
log "3/6 Database secrets from Secrets Manager (values never printed)"
secret() { aws secretsmanager get-secret-value --region "$REGION" --secret-id "$1" --query SecretString --output text; }
MASTER_SECRET_JSON=$(secret "$MASTER_SECRET_ARN")
APP_SECRET_JSON=$(secret "$APP_SECRET_ARN")
APP_PASSWORD=$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["password"])' "$APP_SECRET_JSON")
echo "  master secret : ${MASTER_SECRET_ARN##*:}"
echo "  app secret    : ${APP_SECRET_ARN##*:}"

# ---------------------------------------------------------------------------
log "4/6 Installing the Flask app (web-setup.sh)"
DB_HOST="$DB_HOST" DB_PASSWORD="$APP_PASSWORD" APP_VERSION="$APP_VERSION" BASE_URL="$BASE_URL" bash web-setup.sh

# ---------------------------------------------------------------------------
log "5/6 Initializing the database (once for both instances)"
DB_HOST="$DB_HOST" MASTER_SECRET_JSON="$MASTER_SECRET_JSON" APP_SECRET_JSON="$APP_SECRET_JSON" \
APP_HOSTS="$APP_HOSTS" DB_SSL_CA=/opt/labapp/rds-ca.pem SEED_FILE="$WORK/seed.sql" \
  /opt/labapp/venv/bin/python "$WORK/db_init.py"
unset MASTER_SECRET_JSON APP_SECRET_JSON APP_PASSWORD
systemctl restart labapp

# ---------------------------------------------------------------------------
log "6/6 Readiness check, then signal CloudFormation"
code=000
for _ in $(seq 1 20); do
  code=$(curl -s -o /tmp/ready.json -w '%{http_code}' "http://localhost:8080/health?strict=1" || true)
  [[ "$code" == "200" ]] && break
  sleep 3
done
if [[ "$code" == "200" ]]; then
  echo "  readiness 200: $(cat /tmp/ready.json)"
  signal 0 "App ready: $(md instance-id) in $(md placement/availability-zone), database reachable over TLS"
else
  echo "  readiness ${code}: $(cat /tmp/ready.json 2>/dev/null)"
  signal 1 "Readiness check failed (HTTP ${code}): see /var/log/cloud-init-output.log"
  exit 1
fi
rm -f /tmp/ready.json
echo "==> Bootstrap finished."
