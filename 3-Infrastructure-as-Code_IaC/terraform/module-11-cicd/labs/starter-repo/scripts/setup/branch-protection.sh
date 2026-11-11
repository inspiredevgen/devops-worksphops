#!/usr/bin/env bash
# =============================================================================
# EN: Protect main: changes only through pull requests, the checks must pass, code owners must approve.
# FR : Protéger main : changements par pull request seulement, vérifications réussies, approbation des propriétaires du code.
# Usage: scripts/setup/branch-protection.sh owner/repo
# =============================================================================
set -euo pipefail
REPO="${1:?usage: $0 owner/repo}"

gh api --method PUT "repos/${REPO}/branches/main/protection" --input - <<'JSON'
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["Quality: fmt, validate, tflint, checkov, policy tests"]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "require_code_owner_reviews": true,
    "dismiss_stale_reviews": true
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
JSON
echo "✅ main is protected / main est protégée"
