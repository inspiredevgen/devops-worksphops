#!/usr/bin/env bash
# =============================================================================
# EN: Prove a playbook is idempotent. Run from a lab folder (its ansible.cfg + inventory are used).
#   1. ansible-lint (production profile)       → reports shell/command misuse
#   2. run #1  (converge)                      → must not fail
#   3. run #2  (same playbook)                 → must report changed=0
#   4. run #3  (--check --diff)                → must report changed=0: nothing left to do
# FR : Prouve qu'un playbook est idempotent. À lancer depuis un dossier de lab.
#   1. ansible-lint (profil production) · 2. passage 1 (convergence) · 3. passage 2 : changed=0 · 4. --check : changed=0
#
# Usage: ../../shared/advanced/prove-idempotent.sh PLAYBOOK [extra ansible-playbook args…]
# =============================================================================
set -uo pipefail

PLAYBOOK="${1:?usage: prove-idempotent.sh PLAYBOOK [args…]}"
shift
LOG="$(mktemp -d)"
FAIL=0

# EN: Sum one counter (changed, failed, unreachable…) over every host of a PLAY RECAP.
# FR : Additionne un compteur sur tous les hôtes d'un PLAY RECAP.
recap_sum() { awk -v k="$1" '/PLAY RECAP/{r=1;next} r{for(i=1;i<=NF;i++) if($i ~ "^"k"="){split($i,a,"=");s+=a[2]}} END{print s+0}' "$2"; }

run() { # name, extra args…
  local name="$1"; shift
  ANSIBLE_NOCOLOR=1 ANSIBLE_STDOUT_CALLBACK=ansible.builtin.default \
    ansible-playbook "$PLAYBOOK" "$@" >"$LOG/$name.log" 2>&1
  local rc=$?
  printf '%s|%s|%s|%s\n' "$rc" "$(recap_sum changed "$LOG/$name.log")" "$(recap_sum failed "$LOG/$name.log")" "$(recap_sum unreachable "$LOG/$name.log")"
}

echo "== 1. ansible-lint --profile production $PLAYBOOK"
if ansible-lint --profile production "$PLAYBOOK" >"$LOG/lint.log" 2>&1; then
  echo "✅ lint clean"
else
  FAIL=$((FAIL + 1))
  grep -oE '^[a-z][a-z-]+(\[[a-z-]+\])?:' "$LOG/lint.log" | sort | uniq -c | sort -rn | sed 's/^/   /'
  echo "❌ lint: $(grep -oE 'Failed: [0-9]+ failure' "$LOG/lint.log" | head -1) (details: $LOG/lint.log)"
fi

echo "== 2. run #1 (converge)"
IFS='|' read -r rc c f u <<<"$(run run1 "$@")"
if [[ "$rc" -eq 0 ]]; then echo "✅ ok (changed=$c)"; else echo "❌ rc=$rc failed=$f unreachable=$u (see $LOG/run1.log)"; FAIL=$((FAIL + 1)); fi

echo "== 3. run #2 (must be changed=0)"
IFS='|' read -r rc c f u <<<"$(run run2 "$@")"
if [[ "$rc" -eq 0 && "$c" -eq 0 ]]; then
  echo "✅ changed=0"
else
  echo "❌ rc=$rc changed=$c failed=$f. Tasks that still report a change:"
  grep -E '^(changed|ok): \[|^TASK \[' "$LOG/run2.log" | awk '/^TASK/{t=$0;next} /^changed/{print "   " t}' | sort -u
  FAIL=$((FAIL + 1))
fi

echo "== 4. run #3 --check --diff (must be changed=0)"
IFS='|' read -r rc c f u <<<"$(run run3 --check --diff "$@")"
if [[ "$rc" -eq 0 && "$c" -eq 0 ]]; then echo "✅ check mode: nothing to do"; else echo "❌ rc=$rc changed=$c (see $LOG/run3.log)"; FAIL=$((FAIL + 1)); fi
# EN: command/shell tasks are SKIPPED in check mode: a "clean" check run proves nothing about them.
# FR : les tâches command/shell sont SAUTÉES en mode vérification : un passage « propre » ne prouve rien sur elles.
blind=$(( $(recap_sum skipped "$LOG/run3.log") - $(recap_sum skipped "$LOG/run2.log") ))
if [[ "$blind" -gt 0 ]]; then
  echo "⚠️  $blind task run(s) skipped ONLY in check mode (command/shell cannot predict): check mode is blind to them."
fi

echo
if [[ "$FAIL" -eq 0 ]]; then echo "✅ IDEMPOTENT: $PLAYBOOK"; else echo "❌ $FAIL check(s) failed. Logs: $LOG"; fi
exit $(( FAIL > 0 ))
