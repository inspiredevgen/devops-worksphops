#!/bin/bash
# File: scripts/db/proxy-test.sh
# Purpose : Run on 'lab7-admin' after creating the RDS Proxy:
#           1. proxy status, TLS requirement, authentication secret, target health
#           2. DNS + TCP 3306 to the proxy endpoint
#           3. log in as appuser THROUGH the proxy (TLS, server identity verified)
#           4. show multiplexing: 20 client sessions vs the real database connections
#           5. register the proxy endpoint in the secret (key proxy_host) -> the web tier switches to it
# Run     : bash proxy-test.sh [PROXY_NAME=lab7-proxy]
# Options : APP_SECRET=lab7/app/db   REGISTER=0 (test only, do not change the secret)
set -euo pipefail

PROXY_NAME="${1:-lab7-proxy}"
APP_SECRET="${APP_SECRET:-lab7/app/db}"
REGISTER="${REGISTER:-1}"
# RDS Proxy presents a certificate from Amazon Root CA (public): the system trust store verifies it.
SYSTEM_CA=/etc/pki/tls/certs/ca-bundle.crt
[[ -f "$SYSTEM_CA" ]] || SYSTEM_CA=/etc/ssl/certs/ca-certificates.crt

log()  { echo -e "\n\033[1;34m==> $*\033[0m"; }
warn() { echo -e "\033[1;33m[WARN] $*\033[0m"; }
fail() { echo -e "\033[1;31m[FAIL] $*\033[0m"; exit 1; }
json() { python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get(sys.argv[1]) or "")' "$1"; }
cnf_escape() { local v="$1"; printf '%s' "${v//\\/\\\\}"; }

TMP=$(mktemp -d); chmod 700 "$TMP"
trap 'rm -rf "$TMP"' EXIT
if [[ -z "${AWS_REGION:-}" ]]; then
  T=$(curl -sf --noproxy '*' -m 2 -X PUT http://169.254.169.254/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds: 60" || true)
  AWS_REGION=$(curl -sf --noproxy '*' -m 2 -H "X-aws-ec2-metadata-token: $T" http://169.254.169.254/latest/meta-data/placement/region || echo us-west-1)
fi
export AWS_REGION AWS_DEFAULT_REGION="$AWS_REGION"
command -v mysql >/dev/null || fail "Run db-init.sh first (it installs the MySQL client)."

# ---------------------------------------------------------------------------
log "1/5 Proxy ${PROXY_NAME}: configuration and targets"
aws rds describe-db-proxies --db-proxy-name "$PROXY_NAME" --output json > "$TMP/proxy.json" \
  || fail "Proxy ${PROXY_NAME} not found (or lab7-admin-role lacks rds:DescribeDBProxies)."
read -r PROXY_HOST PSTATUS REQUIRE_TLS AUTH_SECRET < <(python3 - "$TMP/proxy.json" <<'EOF'
import json, sys
p = json.load(open(sys.argv[1]))["DBProxies"][0]
auth = ",".join(a.get("SecretArn", "-").split(":")[-1] for a in p.get("Auth", []))
print(p["Endpoint"], p["Status"], p["RequireTLS"], auth or "-")
EOF
)
echo "Endpoint     : ${PROXY_HOST}"
echo "Status       : ${PSTATUS}"
echo "Require TLS  : ${REQUIRE_TLS}"
echo "Auth secret  : ${AUTH_SECRET}"
[[ "$PSTATUS" == "available" ]] || warn "Proxy status is '${PSTATUS}': wait for 'available' (5-10 minutes after creation)."
[[ "$REQUIRE_TLS" == "True" ]] || warn "Require TLS is off: edit the proxy and enable it (best practice)."
[[ "$AUTH_SECRET" == "${APP_SECRET}"* ]] || warn "The proxy does not use ${APP_SECRET}: appuser logins through the proxy will fail."
echo "Targets:"
aws rds describe-db-proxy-targets --db-proxy-name "$PROXY_NAME" \
  --query 'Targets[].[RdsResourceId,Type,TargetHealth.State,TargetHealth.Reason,TargetHealth.Description]' --output table \
  || warn "Cannot read the targets (rds:DescribeDBProxyTargets)."

# ---------------------------------------------------------------------------
log "2/5 DNS and TCP 3306 to the proxy"
PIP=$(getent hosts "$PROXY_HOST" | awk '{print $1}' | head -1 || true)
[[ -n "$PIP" ]] || fail "Cannot resolve ${PROXY_HOST}."
echo "Resolves to ${PIP} (an elastic network interface of the proxy in your private subnets)"
nc -z -w 5 "$PROXY_HOST" 3306 && echo "OK: TCP 3306 reachable (lab7-proxy-sg allows lab7-admin-sg)" \
  || fail "TCP 3306 timed out: lab7-proxy-sg needs inbound 3306 from lab7-admin-sg (and from lab7-web-sg)."

# ---------------------------------------------------------------------------
log "3/5 appuser login THROUGH the proxy (TLS, certificate + host name verified)"
aws secretsmanager get-secret-value --secret-id "$APP_SECRET" --query SecretString --output text > "$TMP/app.json" \
  || fail "Cannot read ${APP_SECRET}. Run db-init.sh first."
printf '[client]\nuser=%s\npassword="%s"\n' "$(json username < "$TMP/app.json")" \
  "$(cnf_escape "$(json password < "$TMP/app.json")")" > "$TMP/app.cnf"
psql_() { mysql --defaults-extra-file="$TMP/app.cnf" -h "$PROXY_HOST" -P 3306 --ssl-mode=VERIFY_IDENTITY --ssl-ca="$SYSTEM_CA" "$@"; }
if ! psql_ labapp -t -e "SELECT CURRENT_USER() AS user_seen_by_db, @@hostname AS db_host, VERSION() AS version,
                         (SELECT COUNT(*) FROM students) AS students;"; then
  cat <<EOF
  Login through the proxy failed. Check, in this order:
   - Proxy -> Authentication: secret ${APP_SECRET}, IAM authentication 'Not allowed'
   - Proxy targets above: State must be AVAILABLE (AUTH_FAILURE = the proxy cannot log in to the DB
     with the secret: run db-init.sh again; PENDING_PROXY_CAPACITY / UNAVAILABLE: wait or check lab7-rds-sg)
   - lab7-rds-sg must allow 3306 from lab7-proxy-sg
EOF
  exit 1
fi
echo "Note: user_seen_by_db shows appuser@10.10.x.% : MySQL sees the proxy's private IP, not lab7-admin."

# ---------------------------------------------------------------------------
log "4/5 Connection pooling: 20 short client sessions, one after the other"
# Each 'mysql' run = a new client connection: login, one query, disconnect (like a busy web app).
RDS_HOST=$(json host < "$TMP/app.json")
RDS_CA="${HOME}/.lab7/rds-ca.pem"
direct_ids=""; proxy_ids=""
for _ in $(seq 1 20); do
  proxy_ids+="$(psql_ -N -e "SELECT CONNECTION_ID()" 2>/dev/null) "
  if [[ -f "$RDS_CA" ]]; then
    direct_ids+="$(mysql --defaults-extra-file="$TMP/app.cnf" -h "$RDS_HOST" --ssl-mode=VERIFY_IDENTITY \
                   --ssl-ca="$RDS_CA" -N -e "SELECT CONNECTION_ID()" 2>/dev/null) "
  fi
done
count() { tr ' ' '\n' <<<"$1" | grep -c . || true; }
uniq_count() { tr ' ' '\n' <<<"$1" | grep . | sort -u | wc -l; }
printf "  %-22s %-18s %s\n" "PATH" "CLIENT SESSIONS" "DISTINCT DATABASE CONNECTIONS"
[[ -n "$direct_ids" ]] && printf "  %-22s %-18s %s\n" "direct to RDS" "$(count "$direct_ids")" "$(uniq_count "$direct_ids")"
printf "  %-22s %-18s %s\n" "through RDS Proxy" "$(count "$proxy_ids")" "$(uniq_count "$proxy_ids")"
echo "Direct: every client login opens (and pays for) a new MySQL connection."
echo "Proxy : client sessions are served by a few pooled database connections that stay open."
echo "At scale, compare CloudWatch -> RDS Proxy metrics ClientConnections vs DatabaseConnections."

# ---------------------------------------------------------------------------
if [[ "$REGISTER" == "1" ]]; then
  log "5/5 Registering the proxy in ${APP_SECRET} (key proxy_host)"
  python3 - "$TMP/app.json" "$PROXY_HOST" <<'EOF'
import json, os, sys
p = sys.argv[1]
d = json.load(open(p)); d["proxy_host"] = sys.argv[2]
fd = os.open(p, os.O_WRONLY | os.O_TRUNC); os.write(fd, json.dumps(d).encode()); os.close(fd)
EOF
  aws secretsmanager put-secret-value --secret-id "$APP_SECRET" --secret-string "file://$TMP/app.json" \
    --query VersionId --output text | sed 's/^/New secret version: /'
  echo "Running web servers switch to the proxy within 5 minutes (secret cache) - new instances immediately."
else
  log "5/5 REGISTER=0: secret unchanged"
fi
