#!/bin/bash
# File: db/db-init.sh
# Purpose : Initialize the Amazon RDS for MySQL database from the BASTION host:
#           create the 'labapp' database, the least-privilege 'appuser' account
#           (allowed only from the two app subnets), and load seed.sql.
# Run     : bash db-init.sh <RDS_ENDPOINT>
#           (you are prompted for the RDS master password; it is never written to disk)
# Options : MASTER_USER=admin           RDS master user name
#           APP_PASSWORD='...'          reuse a specific appuser password
#           APP_HOSTS='10.20.11.% 10.20.12.%'   MySQL host patterns for appuser
#           DB_TLS=off                  disable TLS (troubleshooting only)
set -euo pipefail

RDS_HOST="${1:-${RDS_HOST:-}}"
if [[ -z "$RDS_HOST" ]]; then
  echo "Usage: bash db-init.sh <RDS_ENDPOINT>"
  echo "Example: bash db-init.sh lab2-mysql.abcdefgh1234.us-west-1.rds.amazonaws.com"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
SEED_FILE="${SCRIPT_DIR}/seed.sql"
MASTER_USER="${MASTER_USER:-admin}"
DB_NAME="labapp"
APP_USER="appuser"
APP_HOSTS="${APP_HOSTS:-10.20.11.% 10.20.12.%}"     # lab2-app-a and lab2-app-b only
DB_TLS="${DB_TLS:-on}"
CA_FILE="${HOME}/rds-ca.pem"
APP_PW_FILE="${HOME}/lab2-appuser.txt"

log()  { echo -e "\n\033[1;34m==> $*\033[0m"; }
warn() { echo -e "\033[1;33m[WARN] $*\033[0m"; }
fail() { echo -e "\033[1;31m[FAIL] $*\033[0m"; exit 1; }
rand() { python3 -c 'import secrets; print(secrets.token_hex(6))'; }

[[ -f "$SEED_FILE" ]] || fail "seed.sql not found next to this script ($SEED_FILE)."
[[ $EUID -ne 0 ]] || warn "You don't need sudo for this script (it asks for sudo only to install packages)."

# ---------------------------------------------------------------------------
log "1/5 Installing the MySQL client and network test tools (if needed)"
if ! command -v nc >/dev/null 2>&1; then
  sudo dnf -y install nmap-ncat
fi
if ! mysql --version 2>/dev/null | grep -q 'Ver 8\.'; then   # MySQL 8.x client (handles caching_sha2_password)
  sudo tee /etc/yum.repos.d/mysql-community.repo >/dev/null <<'EOF'
[mysql-8.4-lts-community]
name=MySQL 8.4 LTS Community Server
baseurl=https://repo.mysql.com/yum/mysql-8.4-community/el/9/$basearch/
enabled=1
gpgcheck=1
gpgkey=https://repo.mysql.com/RPM-GPG-KEY-mysql-2023
EOF
  sudo dnf -y install mysql-community-client
fi
mysql --version

# ---------------------------------------------------------------------------
log "2/5 Testing the network path bastion -> RDS ${RDS_HOST}:3306"
RDS_IP=$(getent hosts "$RDS_HOST" | awk '{print $1}' | head -1 || true)
[[ -n "$RDS_IP" ]] || fail "Cannot resolve ${RDS_HOST}. Copy the endpoint from RDS -> Databases -> lab2-mysql -> Connectivity & security."
echo "Endpoint resolves to ${RDS_IP} (a PRIVATE address: the database has no public access)"
if nc -z -w 5 "$RDS_HOST" 3306; then
  echo "OK: TCP 3306 reachable"
else
  fail "TCP 3306 timed out. Check lab2-db-sg: inbound MYSQL/Aurora 3306 from lab2-bastion-sg, and that the DB status is 'Available'."
fi

# ---------------------------------------------------------------------------
MYSQL_ARGS=(-h "$RDS_HOST" -P 3306)
if [[ "$DB_TLS" == "on" ]]; then
  log "3/5 Downloading the Amazon RDS CA bundle (TLS encryption in transit)"
  curl -fsSL https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem -o "$CA_FILE"
  MYSQL_ARGS+=(--ssl-mode=VERIFY_IDENTITY --ssl-ca="$CA_FILE")
  echo "CA bundle saved to ${CA_FILE}; connections verify the RDS server certificate."
else
  log "3/5 TLS disabled (DB_TLS=off) - troubleshooting mode only"
fi

# ---------------------------------------------------------------------------
log "4/5 Logging in as the RDS master user '${MASTER_USER}'"
if [[ -z "${MASTER_PASSWORD:-}" ]]; then
  echo "Find it in: Secrets Manager -> secret 'rds!db-...' -> Retrieve secret value -> password"
  read -rsp "RDS master password: " MASTER_PASSWORD
  echo
fi

# Temporary option file so the password never appears in the process list.
# Quoted value: in MySQL option files an unquoted '#' starts a comment.
TMP_CNF=$(mktemp)
trap 'rm -f "$TMP_CNF"' EXIT
chmod 600 "$TMP_CNF"
# Escape backslashes too: RDS-generated passwords may contain them.
printf '[client]\nuser=%s\npassword="%s"\n' "$MASTER_USER" "${MASTER_PASSWORD//\\/\\\\}" > "$TMP_CNF"
unset MASTER_PASSWORD

sql() { mysql --defaults-extra-file="$TMP_CNF" "${MYSQL_ARGS[@]}" "$@"; }

if ! sql -N -e "SELECT CONCAT('Connected to ', @@hostname, ' running MySQL ', VERSION())"; then
  fail "Login failed. Check the master user name (${MASTER_USER}) and password. If the error mentions SSL, retry with DB_TLS=off to isolate the problem."
fi
TLS_CIPHER=$(sql -N -e "SHOW SESSION STATUS LIKE 'Ssl_cipher'" | awk '{print $2}')
echo "Encryption in transit: ${TLS_CIPHER:-none}"

# ---------------------------------------------------------------------------
log "5/5 Creating database '${DB_NAME}', user '${APP_USER}', and loading seed.sql"
if [[ -z "${APP_PASSWORD:-}" && -f "$APP_PW_FILE" ]]; then
  APP_PASSWORD=$(cat "$APP_PW_FILE")
  echo "Re-using the appuser password saved in ${APP_PW_FILE}"
fi
APP_PASSWORD="${APP_PASSWORD:-App#$(rand)Aa9}"
( umask 077; printf '%s' "$APP_PASSWORD" > "$APP_PW_FILE" )

{
  echo "CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
  for h in $APP_HOSTS; do
    echo "CREATE USER IF NOT EXISTS '${APP_USER}'@'${h}' IDENTIFIED BY '${APP_PASSWORD}';"
    echo "ALTER USER '${APP_USER}'@'${h}' IDENTIFIED BY '${APP_PASSWORD}';"
    echo "GRANT SELECT, INSERT, UPDATE, DELETE ON ${DB_NAME}.* TO '${APP_USER}'@'${h}';"
  done
} | sql

sql "$DB_NAME" < "$SEED_FILE"

echo
sql -t "$DB_NAME" -e "SELECT 'courses' AS table_name, COUNT(*) AS row_count FROM courses
                      UNION ALL SELECT 'students', COUNT(*) FROM students
                      UNION ALL SELECT 'enrollments', COUNT(*) FROM enrollments;"
sql -t -e "SELECT user, host FROM mysql.user WHERE user='${APP_USER}' ORDER BY host;"

cat <<EOF

=====================================================================
 RDS database initialized
   Endpoint      : ${RDS_HOST}
   Database      : ${DB_NAME}
   App user      : ${APP_USER}  (allowed from: ${APP_HOSTS})
   App password  : ${APP_PASSWORD}

 NEXT (Part 10 of the lab): create the Secrets Manager secret
   Secret type : Credentials for Amazon RDS database
   User name   : ${APP_USER}
   Password    : ${APP_PASSWORD}
   Database    : lab2-mysql
   Secret name : lab2/labapp/db

 The password is also saved (owner-only) in ${APP_PW_FILE}.
 Re-running this script keeps the same password and resets the sample data.
=====================================================================
EOF
