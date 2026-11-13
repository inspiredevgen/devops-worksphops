#!/usr/bin/env bash
# =============================================================================
# EN: Self-check for the pattern exercises. Write ONE pattern per line in answers.txt (8 lines), then run this.
# FR : Auto-correction des exercices de motifs. Écrivez UN motif par ligne dans answers.txt (8 lignes), puis lancez ceci.
# =============================================================================
set -uo pipefail
ANS="$(realpath "${1:-answers.txt}" 2>/dev/null || echo "${1:-answers.txt}")"
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 2
[[ -f "$ANS" ]] || { echo "❌ $ANS not found / introuvable"; exit 2; }

# EN: Expected host sets, sorted, comma-separated. / FR : Ensembles attendus, triés, séparés par des virgules.
EXPECTED=(
  "web01.ca.example,web02.ca.example,web03.ca.example,web04.ca.example"
  "app01.ca.example,app01.eu.example,db01.ca.example,db01.eu.example,web01.ca.example,web02.ca.example"
  "app01.ca.example,db01.ca.example,web01.ca.example,web02.ca.example"
  "app01.ca.example,app01.eu.example,app02.ca.example,db01.ca.example,db01.eu.example"
  "web01.ca.example,web02.ca.example"
  "app02.ca.example,web03.ca.example,web04.ca.example"
  "app01.eu.example,db01.eu.example"
  "web01.ca.example"
)

list() { ansible -i inventory.ini "$1" --list-hosts 2>/dev/null | tail -n +2 | tr -d ' ' | sort | paste -sd, -; }

n=0; score=0
while IFS= read -r pattern || [[ -n "$pattern" ]]; do
  [[ -z "$pattern" || "$pattern" == \#* ]] && continue
  [[ $n -ge ${#EXPECTED[@]} ]] && break
  got="$(list "$pattern")"
  if [[ "$got" == "${EXPECTED[$n]}" ]]; then echo "✅ Q$((n + 1)) '$pattern'"; score=$((score + 1)); else echo "❌ Q$((n + 1)) '$pattern' → ${got:-<no hosts>}"; fi
  n=$((n + 1))
done < "$ANS"
echo "Score: $score/${#EXPECTED[@]}"
[[ $score -eq ${#EXPECTED[@]} ]]
