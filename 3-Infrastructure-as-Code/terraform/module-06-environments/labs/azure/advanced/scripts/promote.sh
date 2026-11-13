#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# EN: Promote the module version from one environment to the NEXT one.
#     Only dev → staging and staging → prod are allowed (no skipping!).
#     Usage: scripts/promote.sh <from> <to> [--plan]
#       --plan  also runs `terraform init -upgrade` + `terraform plan` in <to>
# FR: Promouvoir la version du module d'un environnement vers le SUIVANT.
#     Seuls dev → staging et staging → prod sont autorisés (pas de saut !).
#     Usage : scripts/promote.sh <de> <vers> [--plan]
#       --plan  exécute aussi `terraform init -upgrade` + `terraform plan` dans <vers>
# -----------------------------------------------------------------------------
set -euo pipefail

FROM="${1:-}"
TO="${2:-}"
RUN_PLAN="${3:-}"
LIVE="$(cd "$(dirname "$0")/../live" && pwd)"

case "${FROM}->${TO}" in
  "dev->staging" | "staging->prod") ;;
  *)
    echo "❌ Allowed / Autorisé : dev staging | staging prod  (got / reçu : '${FROM}' '${TO}')" >&2
    exit 1
    ;;
esac

# EN: read the ref from `source = "...?ref=X"` lines only (never from comments)
# FR: lire la réf uniquement dans les lignes `source = "...?ref=X"` (jamais dans les commentaires)
get_ref() {
  grep -E '^[[:space:]]*source[[:space:]]*=' "${LIVE}/$1/main.tf" | grep -oE '\?ref=[^"]+' | head -1 | cut -d= -f2 || true
}

FROM_REF="$(get_ref "${FROM}")"
TO_REF="$(get_ref "${TO}")"

if [ -z "${FROM_REF}" ] || [ -z "${TO_REF}" ]; then
  echo "❌ Could not find ?ref= in live/${FROM} or live/${TO} / ?ref= introuvable" >&2
  exit 1
fi

if [ "${FROM_REF}" = "${TO_REF}" ]; then
  echo "✅ ${TO} already runs ${TO_REF} — nothing to promote / ${TO} utilise déjà ${TO_REF} — rien à promouvoir"
  exit 0
fi

echo "==> Promoting / Promotion : ${FROM} (${FROM_REF}) → ${TO} (${TO_REF} → ${FROM_REF})"
sed -i.bak -E "/^[[:space:]]*source[[:space:]]*=/ s#\\?ref=${TO_REF}\"#?ref=${FROM_REF}\"#" "${LIVE}/${TO}/main.tf"
rm -f "${LIVE}/${TO}/main.tf.bak"

echo
grep -nE '^[[:space:]]*source[[:space:]]*=' "${LIVE}/${TO}/main.tf"
echo

if [ "${RUN_PLAN}" = "--plan" ]; then
  cd "${LIVE}/${TO}"
  terraform init -upgrade -input=false >/dev/null
  terraform plan -input=false
else
  echo "Next / Ensuite :"
  echo "  cd live/${TO} && terraform init -upgrade && terraform plan"
  echo "  git commit -am \"chore(${TO}): promote app-stack ${FROM_REF}\"   # then open a PR / puis ouvrez une PR"
fi
