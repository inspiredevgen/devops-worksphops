#!/bin/bash
# File: scripts/db/rds-init.sh
# Purpose : Run on the BASTION host to set up the Amazon RDS for MySQL database:
#           1. install the MySQL 8.4 client     2. test DNS + TCP 3306 to RDS
#           3. download the RDS CA bundle (TLS) 4. log in as the master user
#           5. create database 'labapp' + least-privilege user 'appuser' (allowed ONLY from the
#              two private web subnets), load seed.sql
#           6. show the accounts and print the command to run on each web server
# Run     : bash rds-init.sh <RDS_ENDPOINT>
#           The master password is asked at a hidden prompt and never written to disk.
# Options : MASTER_USER=admin          RDS master user name
#           APP_HOSTS='10.10.11.% 10.10.12.%'   MySQL host patterns allowed for appuser (web subnets)
#           APP_PASSWORD='...'         use a specific appuser password
#           DB_TLS=off                 disable TLS (troubleshooting only)
set -euo pipefail

RDS_HOST="${1:-${RDS_HOST:-}}"
if [[ -z "$RDS_HOST" ]]; then
  echo "Usage: bash rds-init.sh <RDS_ENDPOINT>"
  echo "Example: bash rds-init.sh lab6-mysql.abcdefgh1234.us-west-1.rds.amazonaws.com"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
SEED_FILE="${SCRIPT_DIR}/seed.sql"
MASTER_USER="${MASTER_USER:-admin}"
DB_NAME="labapp"
APP_USER="appuser"
APP_HOSTS="${APP_HOSTS:-10.10.11.% 10.10.12.%}"
DB_TLS="${DB_TLS:-on}"
STATE_DIR="${HOME}/.lab6"
CA_FILE="${STATE_DIR}/rds-ca.pem"

log()  { echo -e "\n\033[1;34m==> $*\033[0m"; }
warn() { echo -e "\033[1;33m[WARN] $*\033[0m"; }
fail() { echo -e "\033[1;31m[FAIL] $*\033[0m"; exit 1; }
rand() { python3 -c 'import secrets; print(secrets.token_hex(6))'; }
# Escape a value for a double-quoted MySQL option-file entry ('#' is safe inside quotes; '\' is not)
cnf_escape() { local v="$1"; printf '%s' "${v//\\/\\\\}"; }

[[ -f "$SEED_FILE" ]] || fail "seed.sql not found next to this script ($SEED_FILE)."
[[ $EUID -ne 0 ]] || warn "No need for sudo: the script asks for it only to install packages."
mkdir -p "$STATE_DIR" && chmod 700 "$STATE_DIR"

# ---------------------------------------------------------------------------
log "1/6 Installing the MySQL 8.4 client and network tools (if needed)"
command -v nc >/dev/null 2>&1 || sudo dnf -y install nmap-ncat
if ! mysql --version 2>/dev/null | grep -q 'Ver 8\.'; then
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
log "2/6 Checking DNS and the network path bastion -> ${RDS_HOST}:3306"
RDS_IP=$(getent hosts "$RDS_HOST" | awk '{print $1}' | head -1 || true)
[[ -n "$RDS_IP" ]] || fail "Cannot resolve ${RDS_HOST}. Copy the endpoint from RDS -> Databases -> lab6-mysql -> Connectivity & security."
if python3 -c "import ipaddress,sys; sys.exit(0 if ipaddress.ip_address('$RDS_IP').is_private else 1)"; then
  echo "Endpoint resolves to ${RDS_IP}: a PRIVATE address inside the VPC (Public access = No)"
else
  warn "Endpoint resolves to ${RDS_IP}, a PUBLIC address: the instance was created with Public access = Yes."
fi
if nc -z -w 5 "$RDS_HOST" 3306; then
  echo "OK: TCP 3306 reachable (lab6-rds-sg allows lab6-bastion-sg)"
else
  fail "TCP 3306 timed out. Check lab6-rds-sg inbound MYSQL/Aurora 3306 from lab6-bastion-sg, and that the DB status is 'Available'."
fi

# ---------------------------------------------------------------------------
TLS_ARGS=()
if [[ "$DB_TLS" == "on" ]]; then
  log "3/6 Downloading the Amazon RDS CA bundle (TLS)"
  curl -fsSL https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem -o "$CA_FILE"
  TLS_ARGS=(--ssl-mode=VERIFY_IDENTITY --ssl-ca="$CA_FILE")
  echo "Saved ${CA_FILE}. Connections are encrypted AND the RDS server certificate is verified."
else
  log "3/6 TLS disabled (DB_TLS=off): troubleshooting mode only"
fi

# ---------------------------------------------------------------------------
log "4/6 Logging in as the master user '${MASTER_USER}'"
if [[ -z "${MASTER_PASSWORD:-}" ]]; then
  read -rsp "RDS master password: " MASTER_PASSWORD
  echo
fi
TMP_CNF=$(mktemp)
trap 'rm -f "$TMP_CNF"' EXIT
chmod 600 "$TMP_CNF"
printf '[client]\nuser=%s\npassword="%s"\n' "$MASTER_USER" "$(cnf_escape "$MASTER_PASSWORD")" > "$TMP_CNF"
unset MASTER_PASSWORD

admin_sql() { mysql --defaults-extra-file="$TMP_CNF" -h "$RDS_HOST" -P 3306 "${TLS_ARGS[@]}" "$@"; }

if ! admin_sql -N -e "SELECT CONCAT('Connected to ', @@hostname, ' running MySQL ', VERSION())"; then
  fail "Login failed. Check the master user name (${MASTER_USER}) and password. If the error mentions SSL, retry with DB_TLS=off to isolate the problem."
fi
TLS_CIPHER=$(admin_sql -N -e "SHOW SESSION STATUS LIKE 'Ssl_cipher'" | awk '{print $2}')
REQUIRE_TLS=$(admin_sql -N -e "SELECT @@require_secure_transport" 2>/dev/null || echo "?")
echo "Encryption in transit : ${TLS_CIPHER:-none}"
echo "require_secure_transport on the server: ${REQUIRE_TLS} (1 = unencrypted logins are refused)"

# ---------------------------------------------------------------------------
log "5/6 Creating database '${DB_NAME}', user '${APP_USER}', and loading seed.sql"
if [[ -z "${APP_PASSWORD:-}" && -f "${STATE_DIR}/appuser.pw" ]]; then
  APP_PASSWORD=$(cat "${STATE_DIR}/appuser.pw")
  echo "Re-using the appuser password saved in ${STATE_DIR}/appuser.pw"
fi
APP_PASSWORD="${APP_PASSWORD:-App#$(rand)Aa9}"
( umask 077; printf '%s' "$APP_PASSWORD" > "${STATE_DIR}/appuser.pw" )

{
  echo "CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
  for h in $APP_HOSTS; do
    echo "CREATE USER IF NOT EXISTS '${APP_USER}'@'${h}' IDENTIFIED BY '${APP_PASSWORD}';"
    echo "ALTER USER '${APP_USER}'@'${h}' IDENTIFIED BY '${APP_PASSWORD}';"
    echo "GRANT SELECT, INSERT, UPDATE, DELETE ON ${DB_NAME}.* TO '${APP_USER}'@'${h}';"
  done
} | admin_sql

admin_sql "$DB_NAME" < "$SEED_FILE"

# ---------------------------------------------------------------------------
log "6/6 Accounts and data"
admin_sql -t -e "SELECT user, host, plugin FROM mysql.user WHERE user = '${APP_USER}' ORDER BY host;"
admin_sql -t "$DB_NAME" -e "SELECT 'courses' AS table_name, COUNT(*) AS row_count FROM courses
                            UNION ALL SELECT 'students', COUNT(*) FROM students
                            UNION ALL SELECT 'enrollments', COUNT(*) FROM enrollments;"
echo "appuser can log in ONLY from the web subnets: from this bastion (10.10.0.x) MySQL answers 'Access denied'."

cat <<EOF

=====================================================================
 Amazon RDS for MySQL is ready
   Endpoint     : ${RDS_HOST}  (${RDS_IP})
   Database     : ${DB_NAME}
   App user     : ${APP_USER}  allowed from: ${APP_HOSTS}
   App password : ${APP_PASSWORD}
   TLS          : ${TLS_CIPHER:-none}

 NEXT: on EACH web server (lab6-web-a and lab6-web-b), run:
   sudo DB_HOST=${RDS_HOST} DB_PASSWORD='${APP_PASSWORD}' bash web-setup.sh

 The password is saved (owner-only) in ${STATE_DIR}/appuser.pw.
 Re-running this script keeps the same password and resets the sample data.
=====================================================================
EOF
