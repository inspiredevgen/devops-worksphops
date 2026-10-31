#!/bin/bash
# File: scripts/db/db-init.sh
# Purpose : Run on the ADMIN instance 'lab7-admin' (Session Manager, no SSH, no bastion) to:
#           1. install the MySQL 8.4 client          2. find lab7-mysql and its RDS-managed master secret
#           3. test DNS + TCP 3306                    4. log in as master WITHOUT anyone seeing the password
#           5. generate the appuser password, create the database + appuser, load seed.sql
#           6. store the app credentials in Secrets Manager: lab7/app/db  (the password is never displayed)
#           7. prove appuser can log in with the secret
# Run     : bash db-init.sh            (as ssm-user; uses the instance role lab7-admin-role)
# Options : DB_INSTANCE=lab7-mysql   APP_SECRET=lab7/app/db   APP_HOSTS='10.10.11.% 10.10.12.%'
#           SKIP_SEED=1   keep the existing data (re-run safely after a password change)
#           ROTATE=1      generate a NEW appuser password (database + secret updated together)
set -euo pipefail

DB_INSTANCE="${DB_INSTANCE:-lab7-mysql}"
APP_SECRET="${APP_SECRET:-lab7/app/db}"
APP_HOSTS="${APP_HOSTS:-10.10.11.% 10.10.12.%}"
DB_NAME="labapp"
APP_USER="appuser"
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
SEED_FILE="${SCRIPT_DIR}/seed.sql"
WORK="${HOME}/.lab7"; CA_FILE="${WORK}/rds-ca.pem"

log()  { echo -e "\n\033[1;34m==> $*\033[0m"; }
warn() { echo -e "\033[1;33m[WARN] $*\033[0m"; }
fail() { echo -e "\033[1;31m[FAIL] $*\033[0m"; exit 1; }
json() { python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get(sys.argv[1]) or "")' "$1"; }
cnf_escape() { local v="$1"; printf '%s' "${v//\\/\\\\}"; }

[[ -f "$SEED_FILE" ]] || fail "seed.sql not found next to this script ($SEED_FILE)."
mkdir -p "$WORK" && chmod 700 "$WORK"
TMP=$(mktemp -d); chmod 700 "$TMP"
trap 'rm -rf "$TMP"' EXIT

if [[ -z "${AWS_REGION:-}" ]]; then
  T=$(curl -sf --noproxy '*' -m 2 -X PUT http://169.254.169.254/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds: 60" || true)
  AWS_REGION=$(curl -sf --noproxy '*' -m 2 -H "X-aws-ec2-metadata-token: $T" http://169.254.169.254/latest/meta-data/placement/region || echo us-west-1)
fi
export AWS_REGION AWS_DEFAULT_REGION="$AWS_REGION"

# ---------------------------------------------------------------------------
log "1/7 Tools: MySQL 8.4 client, nc, AWS CLI"
command -v nc >/dev/null 2>&1 || sudo dnf -y -q install nmap-ncat
if ! mysql --version 2>/dev/null | grep -q 'Ver 8\.'; then
  sudo tee /etc/yum.repos.d/mysql-community.repo >/dev/null <<'EOF'
[mysql-8.4-lts-community]
name=MySQL 8.4 LTS Community Server
baseurl=https://repo.mysql.com/yum/mysql-8.4-community/el/9/$basearch/
enabled=1
gpgcheck=1
gpgkey=https://repo.mysql.com/RPM-GPG-KEY-mysql-2023
EOF
  sudo dnf -y -q install mysql-community-client
fi
mysql --version
aws --version
aws sts get-caller-identity --query Arn --output text || fail "No AWS credentials: attach the instance profile lab7-admin-role to lab7-admin."

# ---------------------------------------------------------------------------
log "2/7 Looking up ${DB_INSTANCE} (endpoint, master user, RDS-managed master secret)"
aws rds describe-db-instances --db-instance-identifier "$DB_INSTANCE" --output json > "$TMP/db.json" \
  || fail "Cannot describe ${DB_INSTANCE}: wrong name/Region, or lab7-admin-role lacks rds:DescribeDBInstances."
read -r RDS_HOST MASTER_USER MASTER_SECRET_ARN STATUS < <(python3 - "$TMP/db.json" <<'EOF'
import json, sys
d = json.load(open(sys.argv[1]))["DBInstances"][0]
print(d.get("Endpoint", {}).get("Address", "-"), d["MasterUsername"],
      (d.get("MasterUserSecret") or {}).get("SecretArn", "-"), d["DBInstanceStatus"])
EOF
)
echo "Endpoint      : ${RDS_HOST}"
echo "Status        : ${STATUS}"
echo "Master user   : ${MASTER_USER}"
echo "Master secret : ${MASTER_SECRET_ARN}"
[[ "$STATUS" == "available" ]] || warn "The instance is '${STATUS}', not 'available': wait and re-run if the next steps fail."
[[ "$MASTER_SECRET_ARN" != "-" ]] || fail "No RDS-managed master secret. Create the DB with 'Managed in AWS Secrets Manager' (Part 5)."

# ---------------------------------------------------------------------------
log "3/7 DNS and network path lab7-admin -> ${RDS_HOST}:3306"
RDS_IP=$(getent hosts "$RDS_HOST" | awk '{print $1}' | head -1 || true)
[[ -n "$RDS_IP" ]] || fail "Cannot resolve ${RDS_HOST}."
echo "Resolves to ${RDS_IP} (private)"
nc -z -w 5 "$RDS_HOST" 3306 && echo "OK: TCP 3306 reachable (lab7-rds-sg allows lab7-admin-sg)" \
  || fail "TCP 3306 timed out: lab7-rds-sg needs inbound 3306 from lab7-admin-sg."
curl -fsSL --retry 3 https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem -o "$CA_FILE"
TLS=(--ssl-mode=VERIFY_IDENTITY --ssl-ca="$CA_FILE")

# ---------------------------------------------------------------------------
log "4/7 Master login with the RDS-managed secret (the password is never printed)"
aws secretsmanager get-secret-value --secret-id "$MASTER_SECRET_ARN" --query SecretString --output text > "$TMP/master.json" \
  || fail "Cannot read the master secret: lab7-admin-role needs secretsmanager:GetSecretValue on rds!db-*."
MASTER_PW=$(json password < "$TMP/master.json")
printf '[client]\nuser=%s\npassword="%s"\n' "$MASTER_USER" "$(cnf_escape "$MASTER_PW")" > "$TMP/master.cnf"
unset MASTER_PW; rm -f "$TMP/master.json"
admin_sql() { mysql --defaults-extra-file="$TMP/master.cnf" -h "$RDS_HOST" -P 3306 "${TLS[@]}" "$@"; }
admin_sql -N -e "SELECT CONCAT('Connected to ', @@hostname, ' running MySQL ', VERSION(), ' as ', CURRENT_USER())" \
  || fail "Master login failed. If the secret was just rotated, wait one minute and re-run."
echo "TLS: $(admin_sql -N -e "SHOW SESSION STATUS LIKE 'Ssl_cipher'" | awk '{print $2}')"

# ---------------------------------------------------------------------------
log "5/7 Database '${DB_NAME}', user '${APP_USER}' (${APP_HOSTS}), sample data"
EXISTING=""
if aws secretsmanager describe-secret --secret-id "$APP_SECRET" >/dev/null 2>&1; then
  aws secretsmanager get-secret-value --secret-id "$APP_SECRET" --query SecretString --output text > "$TMP/app-old.json"
  EXISTING=yes
fi
if [[ -n "$EXISTING" && "${ROTATE:-0}" != "1" ]]; then
  APP_PW=$(json password < "$TMP/app-old.json")
  echo "Secret ${APP_SECRET} exists: keeping its password (ROTATE=1 to generate a new one)"
else
  # Letters and digits only: safe in every client, config file and URL. 32 chars = plenty of entropy.
  APP_PW=$(aws secretsmanager get-random-password --password-length 32 --exclude-punctuation \
           --require-each-included-type --query RandomPassword --output text)
  echo "Generated a new 32-character password with secretsmanager:GetRandomPassword (not displayed)"
fi
{
  echo "CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
  for h in $APP_HOSTS; do
    echo "CREATE USER IF NOT EXISTS '${APP_USER}'@'${h}' IDENTIFIED BY '${APP_PW}';"
    echo "ALTER USER '${APP_USER}'@'${h}' IDENTIFIED BY '${APP_PW}';"
    echo "GRANT SELECT, INSERT, UPDATE, DELETE ON ${DB_NAME}.* TO '${APP_USER}'@'${h}';"
  done
} > "$TMP/users.sql"
admin_sql < "$TMP/users.sql"; rm -f "$TMP/users.sql"
if [[ "${SKIP_SEED:-0}" == "1" ]]; then
  echo "SKIP_SEED=1: existing data kept"
else
  admin_sql "$DB_NAME" < "$SEED_FILE" && echo "seed.sql loaded (tables dropped and recreated)"
fi
admin_sql -t -e "SELECT user, host, plugin FROM mysql.user WHERE user = '${APP_USER}' ORDER BY host;"

# ---------------------------------------------------------------------------
log "6/7 Storing the app credentials in Secrets Manager: ${APP_SECRET}"
APP_PW="$APP_PW" python3 - "$TMP/app.json" "$TMP/app-old.json" <<EOF
import json, os, sys
old = {}
if os.path.exists(sys.argv[2]):
    old = json.load(open(sys.argv[2]))
new = {"engine": "mysql", "host": "${RDS_HOST}", "port": 3306, "username": "${APP_USER}",
       "password": os.environ["APP_PW"], "dbname": "${DB_NAME}", "dbInstanceIdentifier": "${DB_INSTANCE}"}
if old.get("proxy_host"):
    new["proxy_host"] = old["proxy_host"]          # keep the proxy registered by proxy-test.sh
fd = os.open(sys.argv[1], os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
os.write(fd, json.dumps(new).encode()); os.close(fd)
EOF
if [[ -n "$EXISTING" ]]; then
  aws secretsmanager put-secret-value --secret-id "$APP_SECRET" --secret-string "file://$TMP/app.json" \
    --query '{Name:Name,VersionId:VersionId}' --output table
else
  aws secretsmanager create-secret --name "$APP_SECRET" \
    --description "Lab 7 - appuser credentials for the Node.js web tier and RDS Proxy" \
    --secret-string "file://$TMP/app.json" --tags Key=Project,Value=lab7 \
    --query '{Name:Name,ARN:ARN}' --output table
fi
rm -f "$TMP/app.json" "$TMP/app-old.json"

# ---------------------------------------------------------------------------
log "7/7 Proof: appuser logs in with the credentials read back from the secret"
aws secretsmanager get-secret-value --secret-id "$APP_SECRET" --query SecretString --output text > "$TMP/app.json"
printf '[client]\nuser=%s\npassword="%s"\n' "$APP_USER" "$(cnf_escape "$(json password < "$TMP/app.json")")" > "$TMP/app.cnf"
mysql --defaults-extra-file="$TMP/app.cnf" -h "$RDS_HOST" "${TLS[@]}" "$DB_NAME" -t -e "
  SELECT CURRENT_USER() AS logged_in_as, (SELECT COUNT(*) FROM courses) AS courses,
         (SELECT COUNT(*) FROM students) AS students, (SELECT COUNT(*) FROM enrollments) AS enrollments;" \
  || fail "appuser login failed: is lab7-admin in a private subnet (10.10.11.x / 10.10.12.x)?"
if mysql --defaults-extra-file="$TMP/app.cnf" -h "$RDS_HOST" "${TLS[@]}" -e "CREATE DATABASE hacker" 2>/dev/null; then
  warn "appuser could create a database: privileges are too broad!"
else
  echo "OK: appuser cannot CREATE DATABASE (least privilege)"
fi
PROXY_HOST=$(json proxy_host < "$TMP/app.json")

cat <<EOF

=====================================================================
 Database ready · credentials stored in Secrets Manager
   RDS endpoint : ${RDS_HOST}
   Database     : ${DB_NAME}
   App user     : ${APP_USER}  (allowed from ${APP_HOSTS})
   Secret       : ${APP_SECRET}  (password never displayed)
   Proxy        : ${PROXY_HOST:-not registered yet}

 NEXT:
   Part 7  create the RDS Proxy 'lab7-proxy' with secret ${APP_SECRET}
   then    bash proxy-test.sh lab7-proxy
=====================================================================
EOF
