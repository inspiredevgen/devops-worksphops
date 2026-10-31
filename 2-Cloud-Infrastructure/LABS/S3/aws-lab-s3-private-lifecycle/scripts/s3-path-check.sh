#!/bin/bash
# File: scripts/s3-path-check.sh
# Purpose : Run on lab5-app (PRIVATE subnet). Shows HOW this instance reaches Amazon S3 and
#           what else it can reach, so you can compare the lab phases:
#             Phase 1  NAT only            Phase 2  + S3 gateway endpoint
#             Phase 3  + bucket policy     Phase 4  + endpoint policy     Phase 5  NAT route removed
# Run     : bash s3-path-check.sh <BUCKET_NAME> [--speed]
#           --speed  also uploads/downloads a 50 MB test file and times it
set -euo pipefail
# shellcheck source=common.sh
source "$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/common.sh"

BUCKET="${1:-${BUCKET:-}}"
SPEED="${2:-}"
[[ -n "$BUCKET" ]] || { echo "Usage: bash s3-path-check.sh <BUCKET_NAME> [--speed]"; exit 1; }
BUCKET="${BUCKET#s3://}"; BUCKET="${BUCKET%/}"
T=(--cli-connect-timeout 5 --cli-read-timeout 15)

# ---------------------------------------------------------------------------
log "1/5 Where am I? (instance metadata, IMDSv2)"
# --noproxy: the metadata service must never go through an HTTP proxy; -f: an HTTP error is a failure
TOKEN=$(curl -sf --noproxy '*' -m 2 -X PUT http://169.254.169.254/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds: 120" || true)
md() { curl -sf --noproxy '*' -m 2 -H "X-aws-ec2-metadata-token: $TOKEN" "http://169.254.169.254/latest/meta-data/$1" || true; }
IMDS_REGION=""
[[ -n "$TOKEN" ]] && IMDS_REGION=$(md placement/region)
if [[ "$IMDS_REGION" =~ ^[a-z]{2}(-[a-z]+)+-[0-9]+$ ]]; then
  MAC=$(md mac)
  INSTANCE_ID=$(md instance-id); PRIVATE_IP=$(md local-ipv4); PUBLIC_IP=$(md public-ipv4)
  SUBNET_ID="${SUBNET_ID:-$(md "network/interfaces/macs/${MAC}/subnet-id")}"
  VPC_ID="${VPC_ID:-$(md "network/interfaces/macs/${MAC}/vpc-id")}"
  export AWS_DEFAULT_REGION="${AWS_REGION:-$IMDS_REGION}"
else
  INSTANCE_ID="(not on EC2)"; PRIVATE_IP="-"; PUBLIC_IP=""
  SUBNET_ID="${SUBNET_ID:-}"; VPC_ID="${VPC_ID:-}"
fi
info "Instance ${INSTANCE_ID} · private IP ${PRIVATE_IP} · public IP ${PUBLIC_IP:-none (private subnet)}"
info "Subnet ${SUBNET_ID:-?} · VPC ${VPC_ID:-?} · Region ${AWS_DEFAULT_REGION}"

# ---------------------------------------------------------------------------
log "2/5 The route table of this subnet (decides where packets go)"
HAS_PL="no"; HAS_NAT="no"; EC2_API="ok"
if [[ -n "$SUBNET_ID" ]]; then
  if ROUTES=$(aws ec2 describe-route-tables "${T[@]}" --filters "Name=association.subnet-id,Values=${SUBNET_ID}" \
               --query 'RouteTables[0].Routes[].[DestinationCidrBlock || DestinationPrefixListId, GatewayId || NatGatewayId || TransitGatewayId || `other`, State]' \
               --output text 2>/tmp/rt.err); then
    if [[ -z "$ROUTES" || "$ROUTES" == "None" ]]; then
      ROUTES=$(aws ec2 describe-route-tables "${T[@]}" --filters "Name=vpc-id,Values=${VPC_ID}" "Name=association.main,Values=true" \
               --query 'RouteTables[0].Routes[].[DestinationCidrBlock || DestinationPrefixListId, GatewayId || NatGatewayId || `other`, State]' --output text)
      info "(no explicit association: the subnet uses the VPC's MAIN route table)"
    fi
    printf "    %-26s %-26s %s\n" "DESTINATION" "TARGET" "STATE"
    while read -r dest target state; do
      [[ -z "$dest" ]] && continue
      note=""
      [[ "$dest" == pl-* ]] && { note="<- S3 prefix list (gateway endpoint)"; HAS_PL="yes"; }
      [[ "$target" == nat-* && "$dest" == "0.0.0.0/0" ]] && { note="<- default route via NAT Gateway"; HAS_NAT="yes"; }
      printf "    %-26s %-26s %-10s %s\n" "$dest" "$target" "$state" "$note"
    done <<< "$ROUTES"
  else
    EC2_API="unreachable"
    info "Cannot call the EC2 API: $(tr '\n' ' ' </tmp/rt.err | cut -c1-110)"
    info "Expected when the NAT route is removed: the S3 gateway endpoint gives access to S3 ONLY, not to other AWS APIs."
  fi
else
  EC2_API="unknown"
  info "Subnet unknown (not running on EC2): route table skipped."
fi

# ---------------------------------------------------------------------------
log "3/5 Internet access (via NAT Gateway)"
if EGRESS=$(curl -s -m 5 https://checkip.amazonaws.com 2>/dev/null) && [[ -n "$EGRESS" ]]; then
  INTERNET="yes"; info "Internet OK. The internet sees this instance as ${EGRESS} (the NAT Gateway's Elastic IP)."
else
  INTERNET="no";  info "No internet access (no 0.0.0.0/0 route to a NAT Gateway)."
fi

# ---------------------------------------------------------------------------
log "4/5 Amazon S3 access"
TMP=$(mktemp); trap 'rm -f "$TMP" /tmp/rt.err /tmp/speedtest.bin /tmp/speedtest.down' EXIT
echo "path-check from ${INSTANCE_ID} at $(date -u +%FT%TZ)" > "$TMP"
s3_result() { # description, command...
  local desc="$1"; shift
  if aws_try "$@" "${T[@]}"; then printf "    %-50s %b\n" "$desc" "${GREEN}allowed${NC}"; return 0
  else printf "    %-50s %b %b\n" "$desc" "${RED}denied/failed${NC}" "${DIM}$(err_code)${NC}"; return 1; fi
}
S3_OWN="no"
s3_result "Own bucket: write app/path-check.txt"   aws s3 cp "$TMP" "s3://${BUCKET}/app/path-check.txt" && S3_OWN="yes" || true
s3_result "Own bucket: read it back"               aws s3 cp "s3://${BUCKET}/app/path-check.txt" - || true
s3_result "List ALL buckets (s3:ListAllMyBuckets)" aws s3api list-buckets || true
if command -v dnf >/dev/null 2>&1; then
  if timeout 90 sudo dnf -q makecache --refresh >/dev/null 2>&1; then
    printf "    %-50s %b\n" "OS packages: dnf makecache (AL2023 repos on S3)" "${GREEN}allowed${NC}"
  else
    printf "    %-50s %b\n" "OS packages: dnf makecache (AL2023 repos on S3)" "${RED}denied/failed${NC}"
  fi
fi

if [[ "$SPEED" == "--speed" && "$S3_OWN" == "yes" ]]; then
  dd if=/dev/urandom of=/tmp/speedtest.bin bs=1M count=50 status=none
  START=$(date +%s.%N); aws s3 cp /tmp/speedtest.bin "s3://${BUCKET}/app/speedtest.bin" --only-show-errors; MID=$(date +%s.%N)
  aws s3 cp "s3://${BUCKET}/app/speedtest.bin" /tmp/speedtest.down --only-show-errors; END=$(date +%s.%N)
  aws s3 rm "s3://${BUCKET}/app/speedtest.bin" --only-show-errors || true
  python3 -c "print('    50 MB upload %.1f s · download %.1f s' % ($MID-$START, $END-$MID))"
fi

# ---------------------------------------------------------------------------
log "5/5 Conclusion: how does this instance reach S3?"
if [[ "$HAS_PL" == "yes" ]]; then
  echo -e "    ${GREEN}S3 traffic -> S3 GATEWAY ENDPOINT${NC} (prefix-list route): private AWS network, no NAT, no data-processing charge."
elif [[ "$HAS_NAT" == "yes" ]]; then
  echo -e "    ${YELLOW}S3 traffic -> NAT GATEWAY -> internet gateway -> S3 public endpoint${NC}: works, but every GB is billed by the NAT."
elif [[ "$EC2_API" == "unreachable" && "$S3_OWN" == "yes" && "$INTERNET" == "no" ]]; then
  echo -e "    ${GREEN}S3 works without internet${NC}: only a gateway endpoint can explain it (EC2 API not reachable to confirm)."
else
  echo "    No route to S3 found in the route table."
fi
printf "    Internet: %s · S3 own bucket: %s · EC2 API: %s\n" "$INTERNET" "$S3_OWN" "$EC2_API"
