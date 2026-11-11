#!/usr/bin/env bash
# EN: Install a PINNED Conftest and verify its checksum before running it (supply chain, Module 10).
# FR : Installer une version ÉPINGLÉE de Conftest et vérifier sa somme de contrôle avant de l'exécuter (module 10).
set -euo pipefail
VERSION="0.68.2"
SHA256="e8144c6d6d2ae0260b869caa60c7c262a1f95ac63ec1e5d2fb19be452d606347" # conftest_0.68.2_Linux_x86_64.tar.gz
DEST="${1:-$HOME/.local/bin}"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -sSfL -o "$tmp/conftest.tgz" \
  "https://github.com/open-policy-agent/conftest/releases/download/v${VERSION}/conftest_${VERSION}_Linux_x86_64.tar.gz"
echo "${SHA256}  $tmp/conftest.tgz" | sha256sum -c --quiet
mkdir -p "$DEST"
tar -xzf "$tmp/conftest.tgz" -C "$DEST" conftest
if [[ -n "${GITHUB_PATH:-}" ]]; then echo "$DEST" >> "$GITHUB_PATH"; fi
"$DEST/conftest" --version
