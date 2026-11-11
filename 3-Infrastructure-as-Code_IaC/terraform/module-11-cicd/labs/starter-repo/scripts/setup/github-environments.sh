#!/usr/bin/env bash
# =============================================================================
# EN: Create the GitHub environments the workflows use, with protection rules:
#       app, dev → deployable from main only, no reviewers
#       prod     → deployable from main only, YOU must approve, 2-minute wait timer
#     Needs: gh (logged in, admin on the repo). Required reviewers on PRIVATE repos need a paid plan.
# FR : Créer les environnements GitHub utilisés par les workflows, avec leurs règles de protection :
#       app, dev → déployables depuis main seulement, sans réviseur
#       prod     → déployable depuis main seulement, VOUS devez approuver, délai de 2 minutes
#     Requiert : gh (connecté, admin du dépôt). Les réviseurs obligatoires sur un dépôt PRIVÉ exigent un forfait payant.
# Usage: scripts/setup/github-environments.sh owner/repo
# =============================================================================
set -euo pipefail
REPO="${1:?usage: $0 owner/repo}"
ME_ID="$(gh api user --jq .id)"

create_env() { # name, json-body
  gh api --method PUT "repos/${REPO}/environments/$1" --input - <<<"$2" >/dev/null
  # EN: Only the main branch may deploy here. / FR : Seule la branche main peut déployer ici.
  gh api --method POST "repos/${REPO}/environments/$1/deployment-branch-policies" \
    -f name=main -f type=branch >/dev/null 2>&1 || true
  echo "✅ environment $1"
}

BRANCH_POLICY='"deployment_branch_policy": {"protected_branches": false, "custom_branch_policies": true}'
create_env app  "{${BRANCH_POLICY}}"
create_env dev  "{${BRANCH_POLICY}}"
create_env prod "{${BRANCH_POLICY}, \"wait_timer\": 2, \"reviewers\": [{\"type\": \"User\", \"id\": ${ME_ID}}]}"
