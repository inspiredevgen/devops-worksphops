#!/bin/bash
# File: backend/backend-mysql.sh
# Purpose : Install MySQL 8.4 LTS on Amazon Linux 2023, create the app database/user,
#           and seed it with sample data from seed.sql (same folder).
# Run     : sudo bash ~/backend/backend-mysql.sh
# Options : sudo APP_HOST_PATTERN='10.10.%' DB_APP_PASSWORD='...' bash backend-mysql.sh
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "Please run with sudo."; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
SEED_FILE="${SCRIPT_DIR}/seed.sql"
DB_NAME="labapp"
DB_APP_USER="appuser"
APP_HOST_PATTERN="${APP_HOST_PATTERN:-10.10.%}"   # MySQL host pattern = the VPC CIDR
CRED_FILE="/root/lab-credentials.txt"

log()  { echo -e "\n\033[1;34m==> $*\033[0m"; }
warn() { echo -e "\033[1;33m[WARN] $*\033[0m"; }
rand() { python3 -c 'import secrets; print(secrets.token_hex(6))'; }

[[ -f "$SEED_FILE" ]] || { echo "seed.sql not found next to this script ($SEED_FILE)"; exit 1; }

# Re-use credentials if the script is run a second time
# shellcheck disable=SC1090
[[ -f "$CRED_FILE" ]] && source "$CRED_FILE"
# Passwords satisfy MySQL's validate_password MEDIUM policy (upper, lower, digit, special, >= 8)
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-Root#$(rand)Aa9}"
DB_APP_PASSWORD="${DB_APP_PASSWORD:-App#$(rand)Aa9}"

# Save the passwords BEFORE changing anything, so an interrupted run resumes with the same ones
( umask 077
  cat > "$CRED_FILE" <<EOF
MYSQL_ROOT_PASSWORD='${MYSQL_ROOT_PASSWORD}'
DB_APP_PASSWORD='${DB_APP_PASSWORD}'
EOF
)

# ---------------------------------------------------------------------------
log "1/6 Checking outbound internet access (via the NAT Gateway)"
if EGRESS_IP=$(curl -s --max-time 5 https://checkip.amazonaws.com); then
  echo "Outbound OK. Public egress IP seen by the internet: ${EGRESS_IP} (should be your NAT EIP)"
else
  echo "No outbound internet. Check lab-private-rt: 0.0.0.0/0 -> NAT Gateway, and the NAT is Available."
  exit 1
fi

# ---------------------------------------------------------------------------
log "2/6 Installing the database server"
ENGINE=""
if systemctl list-unit-files mysqld.service >/dev/null 2>&1 && rpm -q mysql-community-server >/dev/null 2>&1; then
  ENGINE="mysql"
elif rpm -q mariadb105-server >/dev/null 2>&1; then
  ENGINE="mariadb"
else
  dnf -y update
  cat > /etc/yum.repos.d/mysql-community.repo <<'EOF'
[mysql-8.4-lts-community]
name=MySQL 8.4 LTS Community Server
baseurl=https://repo.mysql.com/yum/mysql-8.4-community/el/9/$basearch/
enabled=1
gpgcheck=1
gpgkey=https://repo.mysql.com/RPM-GPG-KEY-mysql-2023
EOF
  if dnf -y install mysql-community-server; then
    ENGINE="mysql"
  else
    warn "MySQL repository install failed. Falling back to MariaDB 10.5 (MySQL-compatible)."
    rm -f /etc/yum.repos.d/mysql-community.repo
    dnf -y install mariadb105-server
    ENGINE="mariadb"
  fi
fi
echo "Engine: ${ENGINE}"

# ---------------------------------------------------------------------------
log "3/6 Starting the service"
if [[ "$ENGINE" == "mysql" ]]; then SERVICE="mysqld"; else SERVICE="mariadb"; fi
systemctl enable --now "$SERVICE"
sleep 3

# ---------------------------------------------------------------------------
log "4/6 Securing the root account"
if [[ "$ENGINE" == "mysql" ]]; then
  if mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" -e "SELECT 1" >/dev/null 2>&1; then
    echo "Root password already set."
  else
    TMP_PW=$(grep 'temporary password' /var/log/mysqld.log | tail -1 | awk '{print $NF}')
    [[ -n "$TMP_PW" ]] || { echo "Cannot find the temporary root password in /var/log/mysqld.log"; exit 1; }
    if ! mysql -uroot -p"${TMP_PW}" --connect-expired-password \
         -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';"; then
      echo "Could not log in as root with the saved or the temporary password."
      echo "The root password was probably changed by an earlier run. See Part 12 (troubleshooting)."
      exit 1
    fi
    echo "Temporary root password replaced."
  fi
  # Quote the password: in MySQL option files an unquoted '#' starts a comment
  ( umask 077
    cat > /root/.my.cnf <<EOF
[client]
user=root
password="${MYSQL_ROOT_PASSWORD}"
EOF
  )
else
  echo "MariaDB root uses unix_socket authentication (sudo mysql). No password needed."
fi

sql() {
  if [[ -f /root/.my.cnf ]]; then mysql --defaults-extra-file=/root/.my.cnf "$@"; else mysql "$@"; fi
}

# Remove anonymous users and the test database (what mysql_secure_installation does)
sql -e "DELETE FROM mysql.user WHERE User=''; DROP DATABASE IF EXISTS test; FLUSH PRIVILEGES;"

# ---------------------------------------------------------------------------
log "5/6 Creating database '${DB_NAME}' and user '${DB_APP_USER}'@'${APP_HOST_PATTERN}'"
sql <<SQL
CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_APP_USER}'@'${APP_HOST_PATTERN}' IDENTIFIED BY '${DB_APP_PASSWORD}';
ALTER USER '${DB_APP_USER}'@'${APP_HOST_PATTERN}' IDENTIFIED BY '${DB_APP_PASSWORD}';
GRANT SELECT, INSERT, UPDATE, DELETE ON ${DB_NAME}.* TO '${DB_APP_USER}'@'${APP_HOST_PATTERN}';
FLUSH PRIVILEGES;
SQL

log "   Seeding sample data from seed.sql"
sql "${DB_NAME}" < "$SEED_FILE"

# ---------------------------------------------------------------------------
log "6/6 Verifying"
BIND=$(sql -N -e "SELECT @@bind_address;" 2>/dev/null || echo "unknown")
echo "bind_address = ${BIND}"
if [[ "$BIND" == "127.0.0.1" || "$BIND" == "localhost" ]]; then
  warn "MySQL listens on localhost only. Set bind-address=0.0.0.0 under [mysqld] and restart ${SERVICE}."
fi
ss -ltnp | grep -E ':3306\b' || warn "Nothing is listening on TCP 3306."
sql -t "${DB_NAME}" -e "SELECT 'courses' AS table_name, COUNT(*) AS row_count FROM courses
                        UNION ALL SELECT 'students', COUNT(*) FROM students
                        UNION ALL SELECT 'enrollments', COUNT(*) FROM enrollments;"

TOKEN=$(curl -s -X PUT http://169.254.169.254/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
PRIVATE_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)

cat <<EOF

=====================================================================
 Back-end ready (${ENGINE})
   DB host (private IP) : ${PRIVATE_IP}
   Database             : ${DB_NAME}
   App user             : ${DB_APP_USER}@'${APP_HOST_PATTERN}'
   App password         : ${DB_APP_PASSWORD}
 Copy the private IP and app password into your lab worksheet.
 (Saved in ${CRED_FILE}. View it with: sudo cat ${CRED_FILE})
=====================================================================
EOF
