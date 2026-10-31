#!/bin/bash
# File: web/web-bootstrap.sh
# Purpose : Configure one web server of the Auto Scaling group (Amazon Linux 2023):
#           Apache + PHP-FPM, DB credentials from AWS Secrets Manager, RDS TLS CA bundle,
#           and the LabApp files (lib.php, index.php, health.php) found in the same folder.
# Run by  : user-data.sh at first boot (as root). You can also re-run it by hand:
#           sudo SECRET_ID=lab2/labapp/db bash /opt/labapp-bootstrap/web-bootstrap.sh
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "Please run as root (sudo)."; exit 1; }

SRC="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
SECRET_ID="${SECRET_ID:-lab2/labapp/db}"
APP_DIR="/var/www/labapp"      # outside the web root: credentials, CA bundle, shared library
WEB_ROOT="/var/www/html"

log() { echo -e "\n==> $*"; }

for f in lib.php index.php health.php; do
  [[ -f "$SRC/$f" ]] || { echo "Missing $SRC/$f (download it with the other web files)."; exit 1; }
done

# ---------------------------------------------------------------------------
log "1/6 Reading instance identity from IMDSv2"
TOKEN=$(curl -s -X PUT http://169.254.169.254/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
md() { curl -s -H "X-aws-ec2-metadata-token: $TOKEN" "http://169.254.169.254/latest/meta-data/$1"; }
REGION=$(md placement/region)
AZ=$(md placement/availability-zone)
INSTANCE_ID=$(md instance-id)
PRIVATE_IP=$(md local-ipv4)
echo "Instance ${INSTANCE_ID} in ${AZ} (${REGION}), private IP ${PRIVATE_IP}"

# ---------------------------------------------------------------------------
log "2/6 Installing Apache, PHP-FPM and the PHP MySQL driver"
dnf -y install httpd php php-fpm php-mysqlnd nmap-ncat

# ---------------------------------------------------------------------------
log "3/6 Reading DB credentials from Secrets Manager (secret: ${SECRET_ID})"
SECRET_JSON=""
for attempt in 1 2 3 4 5 6; do
  if SECRET_JSON=$(aws secretsmanager get-secret-value --region "$REGION" --secret-id "$SECRET_ID" \
                     --query SecretString --output text 2>/tmp/secret-error.txt); then
    break
  fi
  echo "  attempt ${attempt}/6 failed: $(tr '\n' ' ' </tmp/secret-error.txt)"
  SECRET_JSON=""
  sleep 10
done
if [[ -z "$SECRET_JSON" ]]; then
  echo "Could not read the secret."
  echo " - AccessDeniedException     -> lab2-web-role inline policy (secret ARN, region, account ID)"
  echo " - ResourceNotFoundException -> secret name must be exactly '${SECRET_ID}'"
  echo " - timeout / could not connect -> lab2-app-rt needs 0.0.0.0/0 -> NAT Gateway"
  echo " - Unable to locate credentials -> attach the IAM instance profile lab2-web-role in the launch template"
  exit 1
fi

# Validate the secret (keys used by lib.php: host, port, username, password, optional dbname)
printf '%s' "$SECRET_JSON" | python3 -c '
import json, sys
d = json.load(sys.stdin)
missing = [k for k in ("host", "username", "password") if not d.get(k)]
if missing:
    sys.exit("Secret is missing keys: " + ", ".join(missing) +
             ". Use the secret type \"Credentials for Amazon RDS database\" and select lab2-mysql.")
print("  Secret OK: user=%s host=%s port=%s dbname=%s" %
      (d["username"], d["host"], d.get("port", 3306), d.get("dbname", "labapp (default)")))
'
mkdir -p "$APP_DIR"
( umask 027; printf '%s' "$SECRET_JSON" > "$APP_DIR/db.json" )
chown root:apache "$APP_DIR/db.json"
chmod 640 "$APP_DIR/db.json"
unset SECRET_JSON

# ---------------------------------------------------------------------------
log "4/6 Downloading the Amazon RDS CA bundle (TLS to the database)"
if curl -fsSL --retry 3 https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem -o "$APP_DIR/rds-ca.pem"; then
  chmod 644 "$APP_DIR/rds-ca.pem"
  echo "  CA bundle installed: connections to RDS are encrypted and the server certificate is verified"
else
  echo "  WARNING: CA bundle download failed. The app will connect WITHOUT TLS."
fi

# ---------------------------------------------------------------------------
log "5/6 Deploying the application and starting services"
install -o root -g apache -m 644 "$SRC/lib.php"    "$APP_DIR/lib.php"
install -o root -g apache -m 644 "$SRC/index.php"  "$WEB_ROOT/index.php"
install -o root -g apache -m 644 "$SRC/health.php" "$WEB_ROOT/health.php"
rm -f "$WEB_ROOT/index.html"

if command -v getenforce >/dev/null 2>&1 && [[ "$(getenforce)" == "Enforcing" ]]; then
  setsebool -P httpd_can_network_connect_db 1
  setsebool -P httpd_can_network_connect 1
fi

systemctl enable --now php-fpm httpd
systemctl restart php-fpm httpd

# ---------------------------------------------------------------------------
log "6/6 Self-tests"
DB_HOST=$(python3 -c 'import json; print(json.load(open("/var/www/labapp/db.json"))["host"])')
DB_PORT=$(python3 -c 'import json; print(json.load(open("/var/www/labapp/db.json")).get("port", 3306))')
if nc -z -w 3 "$DB_HOST" "$DB_PORT"; then
  echo "  OK: ${DB_HOST}:${DB_PORT} reachable (lab2-db-sg allows lab2-web-sg)"
else
  echo "  FAIL: cannot reach ${DB_HOST}:${DB_PORT}. Check lab2-db-sg inbound 3306 from lab2-web-sg."
fi
echo "  Health (strict):"
curl -s "http://localhost/health.php?strict=1" || true
echo
echo "==> Bootstrap complete on ${INSTANCE_ID} (${AZ}). The ALB marks it healthy after 2 successful checks."
