#!/usr/bin/env bash
# =============================================================================
# EN: Measure what forks, ControlPersist and pipelining really buy you, on YOUR fleet.
#     Run it from a lab folder (it uses that folder's ansible.cfg and inventory).
# FR : Mesure ce que forks, ControlPersist et pipelining vous apportent vraiment, sur VOTRE parc.
#     À lancer depuis un dossier de lab (il utilise l'ansible.cfg et l'inventaire de ce dossier).
#
# Usage: ../../shared/measure-tuning.sh [--runs N] [--ssm] [--out FILE]
#   --ssm  EN: SSM connection: only forks is meaningful (no SSH options, no pipelining)
#          FR : connexion SSM : seul forks a un sens (ni options SSH, ni pipelining)
# =============================================================================
set -euo pipefail

RUNS=3
SSM=0
OUT="bench-results.md"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --runs) RUNS="$2"; shift 2 ;;
    --ssm) SSM=1; shift ;;
    --out) OUT="$2"; shift 2 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "Unknown option / option inconnue: $1" >&2; exit 2 ;;
  esac
done

BENCH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/bench.yml"
[[ -f ansible.cfg ]] || { echo "❌ Run from a lab folder (no ansible.cfg here) / Lancez depuis un dossier de lab" >&2; exit 1; }
HOSTS="$(ansible all --list-hosts 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')"
[[ "$HOSTS" -gt 0 ]] || { echo "❌ No hosts in the inventory / aucun hôte" >&2; exit 1; }

# EN: Keep the host-key policy in every profile: tuning must never weaken security.
# FR : On garde la politique de clés d'hôte dans chaque profil : régler ne doit jamais affaiblir la sécurité.
KH="-o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=~/.ssh/known_hosts_ansible_lab"

# name | forks | ssh_args | pipelining
if [[ "$SSM" == 1 ]]; then
  PROFILES=(
    "1 serial (forks=1)|1||False"
    "2 parallel (forks=10)|10||False"
  )
else
  PROFILES=(
    "1 serial, no reuse (forks=1)|1|-o ControlMaster=no $KH|False"
    "2 + parallel (forks=10)|10|-o ControlMaster=no $KH|False"
    "3 + ControlPersist=60s|10|-o ControlMaster=auto -o ControlPersist=60s $KH|False"
    "4 + pipelining|10|-o ControlMaster=auto -o ControlPersist=60s $KH|True"
  )
fi

now() { python3 -c 'import time; print(time.monotonic())'; }

{
  echo "# Tuning benchmark · $(date '+%Y-%m-%d %H:%M') · $HOSTS hosts · 8 tasks/host · median of $RUNS runs"
  echo
  echo "| Profile | Median (s) | All runs (s) |"
  echo "|---|---|---|"
} > "$OUT"

for p in "${PROFILES[@]}"; do
  IFS='|' read -r name forks sshargs pipe <<<"$p"
  times=()
  for ((r = 1; r <= RUNS; r++)); do
    cp_dir="$(mktemp -d)" # EN: fresh ControlPersist sockets for each run / FR : sockets ControlPersist neufs à chaque passage
    t0="$(now)"
    env ANSIBLE_FORKS="$forks" ANSIBLE_PIPELINING="$pipe" ANSIBLE_SSH_CONTROL_PATH_DIR="$cp_dir" \
      ${sshargs:+ANSIBLE_SSH_ARGS="$sshargs"} \
      ansible-playbook "$BENCH" >/dev/null 2>"$cp_dir/err" || { cat "$cp_dir/err" >&2; echo "❌ $name failed / a échoué" >&2; exit 1; }
    t1="$(now)"
    times+=("$(python3 -c "print(f'{$t1 - $t0:.1f}')")")
    rm -rf "$cp_dir"
  done
  median="$(printf '%s\n' "${times[@]}" | sort -n | awk '{a[NR]=$1} END {print (NR % 2) ? a[(NR + 1) / 2] : (a[NR / 2] + a[NR / 2 + 1]) / 2}')"
  printf '| %s | **%s** | %s |\n' "$name" "$median" "${times[*]}" >> "$OUT"
  printf '✅ %-36s median %ss\n' "$name" "$median"
done

echo
cat "$OUT"
echo
echo "EN: Results saved in $OUT (git-ignored). / FR : Résultats enregistrés dans $OUT (ignoré par git)."
