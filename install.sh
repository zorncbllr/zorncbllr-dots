#!/usr/bin/env bash
# zorncbllr-dots installer — Arch Linux only. Symlinks configs with GNU stow.
#
#   ./install.sh [--dry-run] [--no-deps] [--no-system] [--no-chsh] [pkg ...]
#
#   --dry-run    show what would be linked (stow -n); change nothing
#   --no-deps    skip installing packages (yay) and python venv
#   --no-system  skip groups / services / modules (needs sudo)
#   --no-chsh    don't change the login shell to zsh
#   pkg ...      only link these stow packages (default: all in ./stow)
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STOW_DIR="$REPO/stow"
TARGET="${HOME}"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}"
BACKUP="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

DRY=false DEPS=true SYSTEM=true CHSH=true
PKGS=()
for a in "$@"; do
  case $a in
    --dry-run) DRY=true ;;
    --no-deps) DEPS=false ;;
    --no-system) SYSTEM=false ;;
    --no-chsh) CHSH=false ;;
    -h|--help) sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "unknown option: $a" >&2; exit 2 ;;
    *) PKGS+=("$a") ;;
  esac
done

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m==> warning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m==> error:\033[0m %s\n' "$*" >&2; exit 1; }

[[ $EUID -ne 0 ]] || die "run as your normal user, not root"
command -v pacman >/dev/null || die "this installer only supports Arch Linux"

if [[ ${#PKGS[@]} -eq 0 ]]; then
  mapfile -t PKGS < <(find "$STOW_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
fi
for p in "${PKGS[@]}"; do [[ -d $STOW_DIR/$p ]] || die "no such package: $p"; done

# --- dependencies -------------------------------------------------------------
ensure_yay() {
  command -v yay >/dev/null && return
  log "installing yay"
  sudo pacman -S --needed --noconfirm base-devel git
  local tmp; tmp=$(mktemp -d)
  git clone https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
  (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
  rm -rf "$tmp"
}

build_local_pkg() { # PKGBUILDs shipped in sdata/dist-arch that aren't in the AUR
  local dir=$1
  pacman -Qq "${dir##*/}" >/dev/null 2>&1 && return
  log "building ${dir##*/}"
  (cd "$dir" && makepkg -si --noconfirm)
}

install_deps() {
  ensure_yay
  mapfile -t list < <(grep -vE '^\s*(#|$)' "$REPO/packages/packages.txt")
  log "installing ${#list[@]} packages"
  yay -S --needed --noconfirm "${list[@]}"
  for d in "$REPO"/sdata/dist-arch/illogical-impulse-{microtex-git,bibata-modern-classic-bin}; do
    [[ -f $d/PKGBUILD ]] && build_local_pkg "$d"
  done
  # python venv used by the quickshell scripts
  local venv="$STATE/quickshell/.venv"
  if [[ ! -d $venv ]]; then
    log "creating python venv ($venv)"
    mkdir -p "$venv"
    uv venv --prompt .venv "$venv" -p 3.12
    VIRTUAL_ENV="$venv" uv pip install -r "$REPO/sdata/uv/requirements.txt"
  fi
}

setup_system() {
  log "adding $USER to video,i2c,input"
  getent group i2c >/dev/null || sudo groupadd i2c
  sudo usermod -aG video,i2c,input "$USER"
  echo i2c-dev | sudo tee /etc/modules-load.d/i2c-dev.conf >/dev/null
  if [[ -d /run/systemd/system ]]; then
    sudo systemctl enable --now bluetooth || warn "could not enable bluetooth"
    systemctl --user enable --now ydotool 2>/dev/null || warn "ydotool user service not enabled (log in graphically and re-run)"
  fi
}

# --- linking ------------------------------------------------------------------
# Files stow would refuse to overwrite (real files, or links into another place).
conflicts() {
  local pkg=$1
  stow -n --no-folding -d "$STOW_DIR" -t "$TARGET" -R "$pkg" 2>&1 \
    | sed -nE -e 's/.*over existing target (.+) since .*/\1/p' \
              -e 's/.*existing target is not owned by stow: (.+)$/\1/p' | sort -u
}

link_pkg() {
  local pkg=$1 f
  while IFS= read -r f; do
    [[ -n $f && ( -e $TARGET/$f || -L $TARGET/$f ) ]] || continue
    log "backing up ~/$f -> $BACKUP/$f"
    mkdir -p "$BACKUP/$(dirname "$f")"
    mv "$TARGET/$f" "$BACKUP/$f"
  done < <(conflicts "$pkg")
  # --no-folding: only files are symlinked, so files the apps generate at
  # runtime land in the real ~/.config tree and never in this repo.
  stow --no-folding -d "$STOW_DIR" -t "$TARGET" -R "$pkg"
}

command -v stow >/dev/null || { $DEPS && { ensure_yay; sudo pacman -S --needed --noconfirm stow; } || die "stow is required"; }

if $DRY; then
  for p in "${PKGS[@]}"; do
    log "dry run: $p"
    stow -n -v --no-folding -d "$STOW_DIR" -t "$TARGET" -R "$p" 2>&1 | grep -E 'LINK|ERROR|existing' || true
  done
  exit 0
fi

$DEPS && install_deps
for p in "${PKGS[@]}"; do log "linking $p"; link_pkg "$p"; done
$SYSTEM && setup_system

if $CHSH && [[ $(basename "$(getent passwd "$USER" | cut -d: -f7)") != zsh ]]; then
  log "changing login shell to zsh"
  chsh -s "$(command -v zsh)"
fi
command -v pkgfile >/dev/null && { log "building pkgfile database"; sudo pkgfile -u || true; }

log "done. Log out and back in (groups, shell, env). Backups, if any: $BACKUP"
