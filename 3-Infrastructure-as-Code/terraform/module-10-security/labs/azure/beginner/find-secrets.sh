#!/usr/bin/env bash
# EN: Print every attribute in the current state whose NAME looks like a secret, with its value.
# FR : Afficher chaque attribut de l'état courant dont le NOM ressemble à un secret, avec sa valeur.
# Usage: ../find-secrets.sh   (run inside 1-leaky/ or 2-sealed/)
set -euo pipefail
terraform state pull | jq -r '
  .resources[] as $r | $r.instances[]? | .attributes
  | to_entries[]
  | select(.key | test("secret_string|password|result|^value"))
  | "\($r.type).\($r.name).\(.key) = \(.value | tostring)"'
