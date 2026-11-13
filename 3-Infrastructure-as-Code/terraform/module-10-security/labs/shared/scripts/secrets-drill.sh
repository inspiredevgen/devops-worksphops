#!/usr/bin/env bash
# =============================================================================
# secrets-drill.sh — a safe, local drill: leak a FAKE token, catch it 3 ways, see why history matters.
# secrets-drill.sh — un exercice local et sûr : fuiter un FAUX jeton, l'attraper de 3 façons, comprendre l'historique.
#
# EN: The fake token is ASSEMBLED at run time, so this repository never contains a secret-shaped string
#     (that would trip GitHub push protection). Everything happens in a throw-away folder.
# FR : Le faux jeton est ASSEMBLÉ à l'exécution : ce dépôt ne contient jamais de chaîne ressemblant à un secret
#     (cela déclencherait la protection des push de GitHub). Tout se passe dans un dossier jetable.
# Needs / Requiert : git, gitleaks (≥ 8.19)
# =============================================================================
set -uo pipefail
command -v gitleaks >/dev/null || { echo "gitleaks is not installed / gitleaks n'est pas installé"; exit 2; }

DRILL="$(mktemp -d)"
trap 'rm -rf "$DRILL"' EXIT
cd "$DRILL"
git init -q -b main . && git config user.email drill@example.com && git config user.name "Secrets Drill"

FAKE_TOKEN="ghp_""LAB0aB1cD2eF3gH4iJ5kL6mN7oP8qR9sT0uV" # EN: invalid checksum, never a real token / FR : somme de contrôle invalide, jamais un vrai jeton

cat > main.tf <<TF
locals {
  github_token = "${FAKE_TOKEN}" # ❌ a secret in code / un secret dans le code
}
TF

echo; echo "━━ 1. Scan the working folder / Scanner le dossier de travail ━━"
gitleaks dir --no-banner . && echo "(nothing found?) / (rien trouvé ?)"

echo; echo "━━ 2. A pre-commit hook blocks the commit / Un crochet pre-commit bloque le commit ━━"
cat > .git/hooks/pre-commit <<'HOOK'
#!/usr/bin/env bash
gitleaks git --pre-commit --staged --no-banner --redact || {
  echo "🚫 Commit blocked: secret detected / Commit bloqué : secret détecté"; exit 1; }
HOOK
chmod +x .git/hooks/pre-commit
git add main.tf
git commit -q -m "add token" && echo "⚠️ commit went through / le commit est passé" || echo "→ the hook did its job / le crochet a fait son travail"

echo; echo "━━ 3. Bypass the hook, then 'fix' it by deleting the line / Contourner le crochet, puis « corriger » en supprimant la ligne ━━"
git commit -q --no-verify -m "add token (hook bypassed)"
printf 'locals {}\n' > main.tf
git commit -q --no-verify -am "remove token"
echo "Current file / Fichier actuel :"; cat main.tf
gitleaks dir --no-banner . && echo "→ working folder looks clean / le dossier de travail semble propre"

echo; echo "━━ 4. …but the history still has it / …mais l'historique le contient toujours ━━"
gitleaks git --no-banner --redact . || echo "→ the secret is in the history: ROTATE it, then rewrite history / le secret est dans l'historique : RENOUVELEZ-le, puis réécrivez l'historique"
