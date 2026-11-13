#!/usr/bin/env bash
# =============================================================================
# EN: Check the control node. ✅ ok · ⚠️ optional or later module · ❌ must fix before the labs.
# FR : Vérifie le nœud de contrôle. ✅ ok · ⚠️ optionnel ou module ultérieur · ❌ à corriger avant les labs.
# Usage: ./doctor.sh [aws|azure|all]   (default/défaut: all)
# =============================================================================
set -uo pipefail
CLOUD="${1:-all}"
FAIL=0
ok()   { printf '✅ %s\n' "$*"; }
warn() { printf '⚠️  %s\n' "$*"; }
bad()  { printf '❌ %s\n' "$*"; FAIL=$((FAIL + 1)); }
has()  { command -v "$1" >/dev/null 2>&1; }

echo "== Control node / Nœud de contrôle =="
case "$(uname -s)" in
  Linux)  if grep -qi microsoft /proc/version 2>/dev/null; then ok "WSL2"; else ok "Linux"; fi ;;
  Darwin) ok "macOS" ;;
  *)      bad "Unsupported OS (use WSL2 on Windows) / OS non pris en charge (WSL2 sous Windows)" ;;
esac
case "$PWD" in /mnt/[a-z]/*) bad "Working under /mnt/<drive>: move the repo to ~ / Déplacez le dépôt dans ~" ;; esac

if [[ -n "${VIRTUAL_ENV:-}" ]]; then ok "venv active: $VIRTUAL_ENV"; else warn "No venv active / aucun venv actif (source ~/.venvs/ansible-course/bin/activate)"; fi

if has ansible; then
  v="$(ansible --version | head -1)"
  if [[ "$v" =~ core\ 2\.21\. ]]; then ok "$v"; else bad "$v — course needs ansible-core 2.21 / le cours exige 2.21"; fi
  py="$(ansible --version | sed -n 's/^  python version = \([0-9.]*\).*/\1/p')"
  ok "Ansible Python: ${py:-?}"
else
  bad "ansible not found / introuvable — run setup-control-node.sh"
fi
if has ansible-lint; then ok "$(ansible-lint --version 2>/dev/null | head -1)"; else warn "ansible-lint missing / manquant"; fi

if has ansible-galaxy; then
  cols="$(ansible-galaxy collection list 2>/dev/null)"
  for c in amazon.aws community.aws azure.azcollection community.general ansible.posix ansible.windows cloud.terraform; do
    if grep -q "^$c " <<<"$cols"; then ok "collection $c $(grep "^$c " <<<"$cols" | head -1 | awk '{print $2}')"; else bad "collection $c missing / manquante"; fi
  done
fi

echo "== SSH =="
if has ssh; then ok "$(ssh -V 2>&1)"; else bad "ssh client missing / client ssh manquant"; fi
if [[ -f "$HOME/.ssh/id_ed25519.pub" ]]; then ok "key ~/.ssh/id_ed25519.pub"; else bad "No ed25519 key / pas de clé : ssh-keygen -t ed25519 -C \"\$USER@ansible-course\""; fi
if ssh-add -l >/dev/null 2>&1; then ok "ssh-agent has keys / a des clés"; else warn "ssh-agent empty or not running / vide ou arrêté : eval \"\$(ssh-agent)\"; ssh-add"; fi

echo "== Lab hosts (Terraform) =="
if has terraform; then ok "$(terraform version | head -1)"; elif has tofu; then ok "$(tofu version | head -1)"; else bad "terraform (or tofu) missing / manquant"; fi

if [[ "$CLOUD" == aws || "$CLOUD" == all ]]; then
  echo "== AWS =="
  if has aws; then ok "$(aws --version 2>&1)"; else bad "aws CLI missing / manquant"; fi
  if has aws && aws sts get-caller-identity >/dev/null 2>&1; then ok "AWS credentials work / identifiants valides"; else warn "AWS not logged in / non connecté (aws sso login …)"; fi
  if has session-manager-plugin; then ok "session-manager-plugin"; else warn "session-manager-plugin missing (needed for the advanced lab / requis pour le lab avancé)"; fi
  if python3 -c 'import boto3' 2>/dev/null || { [[ -n "${VIRTUAL_ENV:-}" ]] && "$VIRTUAL_ENV/bin/python" -c 'import boto3' 2>/dev/null; }; then ok "boto3"; else bad "boto3 missing in the venv / manquant"; fi
fi

if [[ "$CLOUD" == azure || "$CLOUD" == all ]]; then
  echo "== Azure =="
  if has az; then ok "az $(az version --query '"azure-cli"' -o tsv 2>/dev/null)"; else bad "az CLI missing / manquant"; fi
  if has az && az account show >/dev/null 2>&1; then ok "Azure logged in / connecté"; else warn "Azure not logged in / non connecté (az login)"; fi
  if has az && az extension show --name bastion >/dev/null 2>&1; then ok "az extension bastion"; else warn "az extension add --name bastion (advanced lab / lab avancé)"; fi
fi

echo "== Optional / Optionnel =="
for t in ansible-navigator ansible-builder podman docker code; do
  if has "$t"; then ok "$t"; else warn "$t not installed / non installé"; fi
done

echo
if [[ "$FAIL" -eq 0 ]]; then echo "✅ Ready / Prêt."; else echo "❌ $FAIL item(s) to fix / élément(s) à corriger."; fi
exit $(( FAIL > 0 ))
