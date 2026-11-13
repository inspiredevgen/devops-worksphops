#!/usr/bin/env bash
# =============================================================================
# EN: Pre-release gate for a collection, run from its root BEFORE "git tag":
#       ../path/to/check-release.sh 1.1.0
#     ✔ galaxy.yml version = the version you're releasing  ✔ unit tests  ✔ ansible-lint (production)
#     ✔ changelog fragments lint, and the release is in changelog.yaml  ✔ the collection builds
# FR : Contrôle avant publication d'une collection, depuis sa racine, AVANT « git tag ».
# =============================================================================
set -uo pipefail
VERSION="${1:?usage: check-release.sh <version, e.g. 1.1.0>}"
FAIL=0
ok()  { printf '✅ %s\n' "$*"; }
bad() { printf '❌ %s\n' "$*"; FAIL=$((FAIL + 1)); }

[[ -f galaxy.yml ]] || { echo "❌ run from the collection root (galaxy.yml not found)"; exit 2; }
NS="$(awk '/^namespace:/ {print $2}' galaxy.yml)"; NAME="$(awk '/^name:/ {print $2}' galaxy.yml)"
GALAXY_VERSION="$(awk '/^version:/ {print $2}' galaxy.yml)"

if [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then ok "semantic version $VERSION"; else bad "$VERSION is not MAJOR.MINOR.PATCH"; fi
if [[ "$GALAXY_VERSION" == "$VERSION" ]]; then ok "galaxy.yml version = $VERSION"; else bad "galaxy.yml says $GALAXY_VERSION, not $VERSION"; fi

# EN: ansible-test needs the collection under ansible_collections/<ns>/<name>; pytest only needs it on PYTHONPATH.
# FR : pytest a seulement besoin que la collection soit dans le PYTHONPATH.
TMP="$(mktemp -d)"; mkdir -p "$TMP/ansible_collections/$NS"; ln -s "$PWD" "$TMP/ansible_collections/$NS/$NAME"
if [[ -d tests/unit ]]; then
  if PYTHONPATH="$TMP" python -m pytest -q tests/unit >/dev/null 2>&1; then ok "unit tests"; else bad "unit tests (PYTHONPATH=$TMP python -m pytest tests/unit)"; fi
fi
rm -rf "$TMP"

if ansible-lint --profile production roles >/dev/null 2>&1; then ok "ansible-lint production"; else bad "ansible-lint --profile production roles"; fi

if antsibull-changelog lint >/dev/null 2>&1; then ok "changelog fragments lint"; else bad "antsibull-changelog lint"; fi
if grep -q "^  $VERSION:" changelogs/changelog.yaml 2>/dev/null; then
  ok "$VERSION is in changelogs/changelog.yaml"
else
  bad "$VERSION not released in the changelog: antsibull-changelog release --version $VERSION"
fi

OUT="$(mktemp -d)"
if ansible-galaxy collection build --force --output-path "$OUT" >/dev/null 2>&1 && [[ -f "$OUT/$NS-$NAME-$VERSION.tar.gz" ]]; then
  ok "builds $NS-$NAME-$VERSION.tar.gz"
else
  bad "ansible-galaxy collection build"
fi
rm -rf "$OUT"

echo
if [[ "$FAIL" -eq 0 ]]; then
  echo "✅ Ready: git commit -am 'Release $VERSION' && git tag v$VERSION && git push --follow-tags"
else
  echo "❌ $FAIL check(s) failed: do NOT tag."
fi
exit $(( FAIL > 0 ))
