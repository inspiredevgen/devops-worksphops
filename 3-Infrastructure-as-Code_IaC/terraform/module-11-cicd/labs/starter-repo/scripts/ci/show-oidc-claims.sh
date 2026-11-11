#!/usr/bin/env bash
# =============================================================================
# EN: Ask GitHub for this job's OIDC token and print its CLAIMS, never the token itself.
#     Requires `permissions: id-token: write` on the job.
# FR : Demander à GitHub le jeton OIDC de ce job et afficher ses REVENDICATIONS, jamais le jeton lui-même.
#     Exige `permissions: id-token: write` sur le job.
# Usage: show-oidc-claims.sh [audience]   (default: sts.amazonaws.com)
# =============================================================================
set -euo pipefail
AUDIENCE="${1:-sts.amazonaws.com}"

if [[ -n "${OIDC_TOKEN_FILE:-}" ]]; then # EN: local testing only / FR : tests locaux seulement
  TOKEN="$(cat "$OIDC_TOKEN_FILE")"
else
  : "${ACTIONS_ID_TOKEN_REQUEST_URL:?Missing: add 'permissions: id-token: write' to the job / Manquant : ajoutez 'permissions: id-token: write' au job}"
  TOKEN="$(curl -sSf -H "Authorization: bearer ${ACTIONS_ID_TOKEN_REQUEST_TOKEN}" \
    "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=${AUDIENCE}" | jq -r .value)"
  echo "::add-mask::${TOKEN}"
fi

# EN: A JWT is header.payload.signature, each base64url-encoded without padding.
# FR : Un JWT est en-tête.charge.signature, chacun encodé en base64url sans remplissage.
payload="$(cut -d. -f2 <<<"$TOKEN" | tr '_-' '/+')"
while (( ${#payload} % 4 )); do payload+="="; done
base64 -d <<<"$payload" | jq '{iss, aud, sub, repository, ref, event_name, environment, job_workflow_ref, issued: (.iat | todate), expires: (.exp | todate)}'
