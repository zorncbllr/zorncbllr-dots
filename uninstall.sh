#!/usr/bin/env bash
# Remove the symlinks created by install.sh (packages and your backups are left alone).
#   ./uninstall.sh [--with-sddm] [pkg ...]     --with-sddm also removes the SDDM login theme + config
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
command -v stow >/dev/null || { echo "stow not installed" >&2; exit 1; }
WITH_SDDM=false; ARGS=()
for a in "$@"; do [[ $a == --with-sddm ]] && WITH_SDDM=true || ARGS+=("$a"); done
set -- "${ARGS[@]+"${ARGS[@]}"}"
if [[ $# -eq 0 ]]; then
  mapfile -t PKGS < <(find "$REPO/stow" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
else
  PKGS=("$@")
fi
for p in "${PKGS[@]}"; do
  echo "unlinking $p"
  stow --no-folding -D -d "$REPO/stow" -t "${TARGET:-$HOME}" "$p"
done
if $WITH_SDDM; then
  echo "removing the SDDM login theme (SDDM itself stays enabled and falls back to its default theme)"
  "$REPO/sddm/install-theme.sh" --uninstall
fi
