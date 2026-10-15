#!/usr/bin/env bash
# Install the zorncbllr-lock SDDM theme (login screen styled after the quickshell lock screen).
#
#   ./sddm/install-theme.sh [--wallpaper FILE] [--preview] [--uninstall]
#
#   (default)          copy the theme to /usr/share/sddm/themes, write the SDDM config,
#                      use the current quickshell palette and wallpaper (needs sudo)
#   --wallpaper FILE   use this image instead of the current wallpaper
#   --preview          open the theme in the SDDM greeter's test mode (no root, nothing installed)
#   --uninstall        remove the theme and config (SDDM falls back to its default theme)
#
# Re-run after changing wallpaper or colour scheme to refresh the login screen.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$HERE/zorncbllr-lock"
DEST=/usr/share/sddm/themes/zorncbllr-lock
CONF=/etc/sddm.conf.d/10-zorncbllr.conf
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/user/generated"
WALL=""; MODE=install

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m==> warning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m==> error:\033[0m %s\n' "$*" >&2; exit 1; }

while (( $# )); do
  case $1 in
    --wallpaper) WALL=${2:-}; shift ;;
    --preview) MODE=preview ;;
    --uninstall) MODE=uninstall ;;
    -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

# --- pick the wallpaper: --wallpaper, else the current one, else the repo default -----
pick_wallpaper() {
  [[ -n $WALL ]] && { echo "$WALL"; return; }
  local cur=""; [[ -r $STATE/wallpaper/path.txt ]] && cur=$(<"$STATE/wallpaper/path.txt")
  if [[ -n $cur && -f $cur ]]; then
    case "${cur,,}" in *.png|*.jpg|*.jpeg|*.webp|*.bmp) echo "$cur"; return ;; esac
  fi
  echo "$HERE/../stow/quickshell/.config/quickshell/ii/assets/images/default_wallpaper.png"
}

# --- theme.conf with the current palette (falls back to the monochrome defaults) --------
render_conf() { # render_conf OUTFILE
  cp "$SRC/theme.conf" "$1"
  local colors="$STATE/colors.json"
  [[ -r $colors ]] && command -v jq >/dev/null || return 0
  local k v
  for pair in surfaceContainer:surface_container surfaceContainerHigh:surface_container_high \
              onSurface:on_surface onSurfaceVariant:on_surface_variant \
              primary:primary onPrimary:on_primary error:error; do
    k=${pair%%:*}; v=$(jq -r --arg n "${pair##*:}" '.[$n] // empty' "$colors")
    [[ $v =~ ^#[0-9a-fA-F]{6,8}$ ]] && sed -i -E "s|^${k}=.*|${k}=${v}|" "$1"
  done
}

case $MODE in
  preview)
    command -v sddm-greeter-qt6 >/dev/null || die "sddm-greeter-qt6 not found (install sddm)"
    tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
    cp -r "$SRC/." "$tmp/"; render_conf "$tmp/theme.conf"
    cp "$(pick_wallpaper)" "$tmp/background.png"
    log "opening the greeter in test mode (close the window to quit)"
    sddm-greeter-qt6 --test-mode --theme "$tmp"
    ;;
  uninstall)
    log "removing the theme and SDDM config"
    sudo rm -rf "$DEST" "$CONF"
    ;;
  install)
    command -v sddm >/dev/null || die "sddm is not installed"
    wall=$(pick_wallpaper); [[ -f $wall ]] || die "wallpaper not found: $wall"
    tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
    cp -r "$SRC/." "$tmp/"; render_conf "$tmp/theme.conf"
    cp "$wall" "$tmp/background.png"
    log "installing theme to $DEST (wallpaper: $wall)"
    sudo install -d "$DEST"
    sudo cp -r "$tmp/." "$DEST/"
    sudo chmod -R a+rX "$DEST"
    sudo install -d /etc/sddm.conf.d
    printf '[Theme]\nCurrent=zorncbllr-lock\nCursorTheme=Bibata-Modern-Classic\n' | sudo tee "$CONF" >/dev/null
    log "done. The new login screen shows from the next logout/reboot."
    ;;
esac
