#!/usr/bin/env bash
# Remove the symlinks created by install.sh (packages and your backups are left alone).
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
command -v stow >/dev/null || { echo "stow not installed" >&2; exit 1; }
if [[ $# -eq 0 ]]; then
  mapfile -t PKGS < <(find "$REPO/stow" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
else
  PKGS=("$@")
fi
for p in "${PKGS[@]}"; do
  echo "unlinking $p"
  stow --no-folding -D -d "$REPO/stow" -t "${TARGET:-$HOME}" "$p"
done
