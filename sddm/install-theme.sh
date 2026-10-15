#!/usr/bin/env bash
# Install the zorncbllr-lock SDDM theme (login screen styled after the quickshell lock screen).
#
#   ./sddm/install-theme.sh [--wallpaper FILE] [--preview] [--uninstall]
#
#   (default)          copy the theme to /usr/share/sddm/themes, write the SDDM config,
#                      use the current quickshell palette and wallpaper (needs sudo)
#   --wallpaper FILE   use this image instead of the current wallpaper
#   --assemble DIR     build the complete theme into DIR (no root, nothing installed)
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
WALL=""; MODE=install; OUT=""

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m==> warning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m==> error:\033[0m %s\n' "$*" >&2; exit 1; }

while (( $# )); do
  case $1 in
    --wallpaper) WALL=${2:-}; shift ;;
    --preview) MODE=preview ;;
    --assemble) MODE=assemble; OUT=${2:-}; shift ;;
    --uninstall) MODE=uninstall ;;
    -h|--help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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
  for pair in surface:surface surfaceContainer:surface_container surfaceContainerHigh:surface_container_high \
              onSurface:on_surface onSurfaceVariant:on_surface_variant outline:outline \
              primary:primary onPrimary:on_primary primaryContainer:primary_container \
              secondary:secondary secondaryContainer:secondary_container \
              onSecondaryContainer:on_secondary_container tertiary:tertiary \
              tertiaryContainer:tertiary_container onTertiaryContainer:on_tertiary_container \
              error:error; do
    k=${pair%%:*}; v=$(jq -r --arg n "${pair##*:}" '.[$n] // empty' "$colors")
    [[ $v =~ ^#[0-9a-fA-F]{6,8}$ ]] && sed -i -E "s|^${k}=.*|${k}=${v}|" "$1"
  done
  # Clock settings from the shell config: where the clock sits on the desktop (the unlock
  # animation ends there), its number of sides and the time format.
  local cfg="${XDG_CONFIG_HOME:-$HOME/.config}/illogical-impulse/config.json" val
  [[ -r $cfg ]] || return 0
  for pair in clockX:.background.widgets.clock.x clockY:.background.widgets.clock.y \
              cookieSides:.background.widgets.clock.cookie.sides timeFormat:.time.format; do
    k=${pair%%:*}; val=$(jq -r "${pair#*:} // empty" "$cfg")
    [[ -n $val && $val != *,* ]] && sed -i -E "s|^${k}=.*|${k}=${val}|" "$1"
  done
  return 0
}

# --- assemble the complete theme in DIR: sources, palette, wallpaper, shapes lib, fonts ----
SHAPES="$HERE/../stow/quickshell/.config/quickshell/ii/modules/common/widgets/shapes"
GSF_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/illogical-impulse-google-sans-flex"
assemble() { # assemble DIR
  local out=$1 wall font
  wall=$(pick_wallpaper); [[ -f $wall ]] || die "wallpaper not found: $wall"
  [[ -d $SHAPES ]] || die "shapes library missing at $SHAPES"
  cp -r "$SRC/." "$out/"
  render_conf "$out/theme.conf"
  cp "$wall" "$out/background.png"
  # rounded-polygon library (Material shapes): everything except examples/VCS files
  mkdir -p "$out/shapes"
  rsync -a --exclude='.git*' --exclude='example*' --exclude='README.md' "$SHAPES/" "$out/shapes/"
  # Google Sans Flex lives in the user's font dir, which the sddm user cannot read
  font=$(ls "$GSF_DIR"/GoogleSansFlex*.ttf 2>/dev/null | head -1 || true)
  mkdir -p "$out/fonts"
  if [[ -n $font ]]; then cp "$font" "$out/fonts/GoogleSansFlex.ttf"; else warn "Google Sans Flex not found; using Rubik"; fi
  echo "$wall"
}

case $MODE in
  assemble)
    [[ -n $OUT ]] || die "--assemble needs a directory"
    mkdir -p "$OUT"; assemble "$OUT" >/dev/null
    log "theme assembled in $OUT"
    ;;
  preview)
    command -v sddm-greeter-qt6 >/dev/null || die "sddm-greeter-qt6 not found (install sddm)"
    tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
    assemble "$tmp" >/dev/null
    printf 'showPowerAlways=true\n' >> "$tmp/theme.conf"   # test mode reports no power actions
    log "opening the greeter in test mode (close the window to quit)"
    QML_XHR_ALLOW_FILE_READ=1 sddm-greeter-qt6 --test-mode --theme "$tmp"
    ;;
  uninstall)
    log "removing the theme and SDDM config"
    sudo rm -rf "$DEST" "$CONF"
    ;;
  install)
    command -v sddm >/dev/null || die "sddm is not installed"
    tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
    wall=$(assemble "$tmp")
    log "installing theme to $DEST (wallpaper: $wall)"
    sudo rm -rf "$DEST"            # drop files from older versions
    sudo install -d "$DEST"
    sudo cp -r "$tmp/." "$DEST/"
    sudo chmod -R a+rX "$DEST"
    sudo install -d /etc/sddm.conf.d
    # GreeterEnvironment lets the theme read /sys/class/power_supply (battery indicator)
    printf '[Theme]\nCurrent=zorncbllr-lock\nCursorTheme=Bibata-Modern-Classic\n\n[General]\nGreeterEnvironment=QML_XHR_ALLOW_FILE_READ=1\n' | sudo tee "$CONF" >/dev/null
    log "done. The new login screen shows from the next logout/reboot."
    ;;
esac
