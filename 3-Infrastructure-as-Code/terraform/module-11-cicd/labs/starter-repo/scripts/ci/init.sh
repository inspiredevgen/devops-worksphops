#!/usr/bin/env bash
# =============================================================================
# EN: terraform init with the right partial backend for $CLOUD (aws|azure) and $STATE_KEY.
#     Extra arguments are passed through (e.g. -lockfile=readonly).
# FR : terraform init avec le bon backend partiel pour $CLOUD (aws|azure) et $STATE_KEY.
#     Les arguments supplémentaires sont transmis (ex. -lockfile=readonly).
# =============================================================================
set -euo pipefail
: "${CLOUD:?CLOUD must be aws or azure}" "${STATE_KEY:?STATE_KEY is required}"

case "$CLOUD" in
  aws)
    terraform init -input=false "$@" \
      -backend-config="bucket=${STATE_BUCKET:?}" \
      -backend-config="key=${STATE_KEY}" \
      -backend-config="region=${AWS_REGION:?}" \
      -backend-config="use_lockfile=true"
    ;;
  azure)
    terraform init -input=false "$@" \
      -backend-config="resource_group_name=${STATE_RG:?}" \
      -backend-config="storage_account_name=${STATE_SA:?}" \
      -backend-config="container_name=${STATE_CONTAINER:?}" \
      -backend-config="key=${STATE_KEY}" \
      -backend-config="use_oidc=true" \
      -backend-config="use_azuread_auth=true"
    ;;
  *)
    echo "::error::Unknown CLOUD '${CLOUD}'"
    exit 2
    ;;
esac
