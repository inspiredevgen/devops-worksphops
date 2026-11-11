#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# EN: Show which module version each environment runs (reads `?ref=` in
#     live/<env>/main.tf). Usage: scripts/versions.sh
# FR: Affiche la version du module utilisée par chaque environnement (lit
#     `?ref=` dans live/<env>/main.tf). Usage : scripts/versions.sh
# -----------------------------------------------------------------------------
set -euo pipefail

LIVE="$(cd "$(dirname "$0")/../live" && pwd)"
ENVS=(dev staging prod)

printf "%-10s %s\n" "ENV" "MODULE VERSION"
printf "%-10s %s\n" "---" "--------------"
for env in "${ENVS[@]}"; do
  # EN: only `source = "...?ref=X"` lines, never comments / FR: seulement les lignes `source = …`, jamais les commentaires
  ref="$(grep -E '^[[:space:]]*source[[:space:]]*=' "${LIVE}/${env}/main.tf" | grep -oE '\?ref=[^"]+' | head -1 | cut -d= -f2 || true)"
  printf "%-10s %s\n" "${env}" "${ref:-<none>}"
done
