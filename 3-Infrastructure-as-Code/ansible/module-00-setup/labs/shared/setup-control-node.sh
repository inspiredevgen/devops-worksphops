#!/usr/bin/env bash
# =============================================================================
# EN: Build the course control node: a Python venv with ansible-core + ansible-lint,
#     then the course collections. Linux, macOS or WSL2 (in the Linux filesystem!).
# FR : Construit le nœud de contrôle du cours : un venv Python avec ansible-core + ansible-lint,
#     puis les collections du cours. Linux, macOS ou WSL2 (dans le système de fichiers Linux !).
#
# Usage: ./setup-control-node.sh [--azure] [--venv DIR]
#   --azure   EN: also install the Python SDKs that azure.azcollection needs (big: ~1 GB)
#             FR : installe aussi les SDK Python requis par azure.azcollection (gros : ~1 Go)
# =============================================================================
set -euo pipefail

VENV="${HOME}/.venvs/ansible-course"
AZURE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --azure) AZURE=1; shift ;;
    --venv) VENV="$2"; shift 2 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "Unknown option / option inconnue: $1" >&2; exit 2 ;;
  esac
done

COURSE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

# EN: ansible-core 2.21 needs Python 3.12–3.14 on the control node.
# FR : ansible-core 2.21 exige Python 3.12 à 3.14 sur le nœud de contrôle.
PY=""
for c in python3.14 python3.13 python3.12 python3; do
  if command -v "$c" >/dev/null 2>&1 && "$c" -c 'import sys; sys.exit(0 if (3,12) <= sys.version_info[:2] <= (3,14) else 1)'; then
    PY="$(command -v "$c")"; break
  fi
done
if [[ -z "$PY" ]]; then
  echo "❌ Python 3.12–3.14 not found / introuvable. Ubuntu: sudo apt install python3.12-venv · macOS: brew install python@3.13" >&2
  exit 1
fi
echo "✅ Python: $PY ($("$PY" -V))"

case "$PWD" in
  /mnt/[a-z]/*) echo "⚠️  WSL: you are under /mnt/… — Ansible ignores ansible.cfg in world-writable dirs. Work in ~ instead. / Travaillez dans ~." >&2 ;;
esac

if [[ ! -d "$VENV" ]]; then
  "$PY" -m venv "$VENV"
  echo "✅ venv created / créé: $VENV"
fi
# shellcheck disable=SC1091
source "$VENV/bin/activate"
python -m pip install --quiet --upgrade pip
python -m pip install --quiet -r "$COURSE_ROOT/requirements.txt"
echo "✅ $(ansible --version | head -1)"

ansible-galaxy collection install --upgrade -r "$COURSE_ROOT/requirements.yml"

if [[ "$AZURE" == 1 ]]; then
  REQ="$(python - <<'PY'
import pathlib, ansible_collections.azure.azcollection as c
print(pathlib.Path(c.__path__[0]) / "requirements.txt")
PY
)"
  python -m pip install --quiet -r "$REQ"
  echo "✅ azure.azcollection Python requirements installed / installées"
fi

cat <<MSG

EN: Done. In every new terminal:   source "$VENV/bin/activate"
FR : Terminé. Dans chaque nouveau terminal :   source "$VENV/bin/activate"
Next / Ensuite : $(dirname "${BASH_SOURCE[0]}")/doctor.sh
MSG
