#!/bin/bash
# File: scripts/common.sh
# Shared helpers for the S3 lab scripts. Sourced by the other scripts (not run directly).
# shellcheck disable=SC2034

export AWS_DEFAULT_REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-west-1}}"
export AWS_PAGER=""

BLUE='\033[1;34m'; GREEN='\033[1;32m'; RED='\033[1;31m'; YELLOW='\033[1;33m'; DIM='\033[2m'; NC='\033[0m'
PASS_COUNT=0
FAIL_COUNT=0

log()  { echo -e "\n${BLUE}==> $*${NC}"; }
info() { echo -e "    $*"; }
warn() { echo -e "${YELLOW}[WARN] $*${NC}"; }
fail() { echo -e "${RED}[FAIL] $*${NC}"; exit 1; }

# require_bucket "$@" -> sets BUCKET (from $1 or $BUCKET), checks it is reachable
require_bucket() {
  BUCKET="${1:-${BUCKET:-}}"
  if [[ -z "$BUCKET" ]]; then
    echo "Usage: bash $(basename "$0") <BUCKET_NAME>"
    echo "Example: bash $(basename "$0") lab4-123456789012-ab"
    exit 1
  fi
  BUCKET="${BUCKET#s3://}"; BUCKET="${BUCKET%/}"
  command -v aws >/dev/null 2>&1 || fail "The AWS CLI is not installed (it is pre-installed on Amazon Linux 2023)."
  local err
  if ! err=$(aws s3api head-bucket --bucket "$BUCKET" 2>&1); then
    case "$err" in
      *403*|*Forbidden*) fail "Access denied to bucket '$BUCKET'. Is the IAM role attached to this instance, and its policy using this bucket name?" ;;
      *404*|*"Not Found"*) fail "Bucket '$BUCKET' does not exist (check the name and region ${AWS_DEFAULT_REGION})." ;;
      *credentials*) fail "No AWS credentials. Attach the IAM role to this instance (EC2 -> Actions -> Security -> Modify IAM role)." ;;
      *) fail "Cannot reach bucket '$BUCKET': $err" ;;
    esac
  fi
}

# aws_err "<command...>" -> runs a command, returns its exit code, stores stderr in LAST_ERR
LAST_ERR=""
aws_try() {
  local tmp; tmp=$(mktemp)
  if "$@" >/dev/null 2>"$tmp"; then LAST_ERR=""; rm -f "$tmp"; return 0; fi
  LAST_ERR=$(tr '\n' ' ' <"$tmp" | sed -E 's/^ *//; s/An error occurred //'); rm -f "$tmp"; return 1
}

# Short error code from LAST_ERR, e.g. "AccessDenied", "NoSuchKey", "403"
err_code() {
  local code
  code=$(printf '%s' "$LAST_ERR" | grep -oE '\(([A-Za-z]+|[0-9]{3})\)' | head -1 | tr -d '()')
  [[ -n "$code" ]] || code=$(printf '%s' "$LAST_ERR" | cut -c1-60)
  printf '%s' "$code"
}

# check "<description>" <expect: allow|deny> <command...>
check() {
  local desc="$1" expect="$2"; shift 2
  local result reason=""
  if aws_try "$@"; then result="allow"; else result="deny"; reason="$(err_code)"; fi
  report "$desc" "$expect" "$result" "$reason"
}

# report "<description>" <expected> <actual> [reason]
report() {
  local desc="$1" expect="$2" actual="$3" reason="${4:-}"
  local mark
  if [[ "$expect" == "$actual" ]]; then
    PASS_COUNT=$((PASS_COUNT + 1)); mark="${GREEN}PASS${NC}"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1)); mark="${RED}FAIL${NC}"
  fi
  printf "  %b  %-58s expected %-6s got %-6s %b\n" "$mark" "$desc" "$expect" "$actual" "${DIM}${reason}${NC}"
}

summary() {
  echo
  if [[ $FAIL_COUNT -eq 0 ]]; then
    echo -e "${GREEN}All ${PASS_COUNT} checks behaved as expected.${NC}"
  else
    echo -e "${RED}${FAIL_COUNT} check(s) did not behave as expected${NC} (${PASS_COUNT} passed). See the troubleshooting section of the lab."
  fi
}

# http_status <url> -> prints the HTTP status code (000 = no answer: DNS, network or timeout)
http_status() { curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$1" || true; }
