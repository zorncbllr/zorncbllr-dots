#!/usr/bin/env bash
# zorncbllr-dots installer — Arch Linux only. Symlinks configs with GNU stow.
#
#   ./install.sh [--dry-run] [--no-deps] [--no-system] [--no-chsh] [--verbose] [pkg ...]
#
#   --dry-run    show what would be linked (stow -n); change nothing
#   --no-deps    skip installing packages (yay) and python venv
#   --no-system  skip groups / services / modules (needs sudo)
#   --no-chsh    don't change the login shell to zsh
#   --verbose    show all tool output (default: a log in ~/.local/state/zorncbllr-dots/install.log)
#   pkg ...      only link these stow packages (default: all in ./stow)
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STOW_DIR="$REPO/stow"
TARGET="${HOME}"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}"
BACKUP="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

DRY=false DEPS=true SYSTEM=true CHSH=true VERBOSE=false
PKGS=()
for a in "$@"; do
  case $a in
    --dry-run) DRY=true ;;
    --no-deps) DEPS=false ;;
    --no-system) SYSTEM=false ;;
    --no-chsh) CHSH=false ;;
    --verbose) VERBOSE=true ;;
    -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "unknown option: $a" >&2; exit 2 ;;
    *) PKGS+=("$a") ;;
  esac
done

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m==> warning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m==> error:\033[0m %s\n' "$*" >&2; exit 1; }

# Noisy tools (pacman, yay, makepkg, uv: progress bars, compiler warnings, gpg
# chatter) write to a log; the terminal gets one line per step. On failure the
# log tail is shown. --verbose prints everything instead.
LOGFILE="$STATE/zorncbllr-dots/install.log"
quiet() { # quiet "what" cmd...
  local what=$1; shift
  if $VERBOSE; then log "$what"; "$@"; return; fi
  mkdir -p "$(dirname "$LOGFILE")"
  printf '\n### %s\n$ %s\n' "$what" "$*" >>"$LOGFILE"
  log "$what ..."
  "$@" >>"$LOGFILE" 2>&1 || { warn "$what failed (details: $LOGFILE)"; return 1; }
}
die_log() { # die, but first show the end of the log
  [[ -f $LOGFILE ]] && ! $VERBOSE && { echo "--- last lines of $LOGFILE:" >&2; tail -n 20 "$LOGFILE" | sed 's/^/    /' >&2; }
  die "$@"
}

[[ $EUID -ne 0 ]] || die "run as your normal user, not root"
command -v pacman >/dev/null || die "this installer only supports Arch Linux"

if [[ ${#PKGS[@]} -eq 0 ]]; then
  mapfile -t PKGS < <(find "$STOW_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
fi
for p in "${PKGS[@]}"; do [[ -d $STOW_DIR/$p ]] || die "no such package: $p"; done

# --- dependencies -------------------------------------------------------------
# Network steps are retried: a flaky LAN resolver or mirror must not abort a
# half-finished install. Every retried command is idempotent (--needed, makepkg
# on a fresh copy, uv pip install).
retry() {
  local _try=1 _max=${RETRIES:-4}
  until "$@"; do
    (( _try >= _max )) && return 1
    warn "attempt $_try/$_max failed: $1 ...; retrying in $((_try * 10))s"
    sleep $((_try * 10)); _try=$((_try + 1))
  done
}

check_network() {
  local h
  for h in archlinux.org aur.archlinux.org github.com; do
    retry getent hosts "$h" >/dev/null || die "cannot resolve $h; check your network/DNS and re-run"
  done
}

# Never wait on an interactive prompt (clean-build / diff / edit questions).
YAY_FLAGS=(--needed --noconfirm --answerclean None --answerdiff None --answeredit None --answerupgrade None)

install_yay() {
  local tmp rc; tmp=$(mktemp -d)
  git clone https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin" &&
    (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
  rc=$?; rm -rf "$tmp"; return $rc
}

ensure_yay() {
  command -v yay >/dev/null && return
  retry quiet "installing base-devel and git" sudo pacman -S --needed --noconfirm base-devel git || die_log "could not install base-devel/git"
  retry quiet "installing yay (AUR helper)" install_yay || die_log "could not install yay"
}

build_local_pkg() { # PKGBUILDs shipped in sdata/dist-arch that aren't in the AUR
  local dir=$1 tmp rc
  pacman -Qq "${dir##*/}" >/dev/null 2>&1 && return
  tmp=$(mktemp -d)                  # build in a copy: keep src/ and pkg/ out of the repo
  cp -r "$dir/." "$tmp/"
  (cd "$tmp" && retry quiet "building ${dir##*/} (compiles; can take a few minutes)" makepkg -si --noconfirm)
  rc=$?; rm -rf "$tmp"; return $rc
}

install_missing() {
  local all missing
  mapfile -t all < <(grep -vE '^\s*(#|$)' "$REPO/packages/packages.txt")
  # pacman -T prints only unsatisfied dependencies and honours "provides", so
  # e.g. an installed quickshell-git is not replaced by the repo's quickshell.
  mapfile -t missing < <(pacman -T "${all[@]}" || true)
  if (( ${#missing[@]} )); then
    mkdir -p "$(dirname "$LOGFILE")"; printf '\n### missing packages\n%s\n' "${missing[*]}" >>"$LOGFILE"
    quiet "installing ${#missing[@]} missing package(s) with yay (AUR packages are built; can take a while)" \
      yay -S "${YAY_FLAGS[@]}" "${missing[@]}"
  else
    log "all ${#all[@]} packages already satisfied"
  fi
}

setup_venv() {
  local venv="$STATE/quickshell/.venv"
  # A directory alone proves nothing (an interrupted run leaves one): check for python.
  if [[ ! -x $venv/bin/python ]]; then
    mkdir -p "$venv"
    quiet "creating python venv ($venv)" uv venv --prompt .venv "$venv" -p 3.12 || return 1
  fi
  # no-op when already satisfied
  quiet "installing python requirements" env VIRTUAL_ENV="$venv" uv pip install -r "$REPO/sdata/uv/requirements.txt"
}

install_deps() {
  check_network
  ensure_yay
  retry install_missing || die_log "package installation failed; re-run ./install.sh (it resumes)"
  for d in "$REPO"/sdata/dist-arch/illogical-impulse-{microtex-git,bibata-modern-classic-bin}; do
    [[ -f $d/PKGBUILD ]] && { build_local_pkg "$d" || die_log "failed to build ${d##*/}; re-run ./install.sh"; }
  done
  retry setup_venv || die_log "python venv setup failed; re-run ./install.sh"
}

setup_system() {
  log "adding $USER to video,i2c,input"
  getent group i2c >/dev/null || sudo groupadd i2c
  sudo usermod -aG video,i2c,input "$USER"
  echo i2c-dev | sudo tee /etc/modules-load.d/i2c-dev.conf >/dev/null
  if [[ -d /run/systemd/system ]]; then
    quiet "enabling bluetooth" sudo systemctl enable --now bluetooth || warn "could not enable bluetooth"
    # Login screen styled after the lock screen (only if SDDM is the display manager here).
    if command -v sddm >/dev/null; then
      quiet "installing the SDDM login theme" "$REPO/sddm/install-theme.sh" || warn "SDDM theme not installed; run ./sddm/install-theme.sh"
    fi
    # The user service needs a login session (XDG_RUNTIME_DIR); not an error without one.
    if [[ -z ${XDG_RUNTIME_DIR:-} ]] || ! systemctl --user enable --now ydotool >/dev/null 2>&1; then
      log "ydotool: no user session here; after logging in run: systemctl --user enable --now ydotool"
    fi
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
  seed_files "$pkg"
}

# Files regenerated by the theme pipeline (listed in <pkg>/.seed-files, ignored
# by stow): copied once so the desktop has defaults, never overwritten after.
seed_files() {
  local pkg=$1 rel
  [[ -f $STOW_DIR/$pkg/.seed-files ]] || return 0
  while IFS= read -r rel; do
    [[ -n $rel && ! -e $TARGET/$rel ]] && install -Dm644 "$STOW_DIR/$pkg/$rel" "$TARGET/$rel"
  done < "$STOW_DIR/$pkg/.seed-files"
  return 0
}

# Existing files that would be replaced: how many, and which differ from the repo copy.
report_conflicts() {
  local pkg=$1 f total=0 differ=()
  while IFS= read -r f; do
    [[ -n $f ]] || continue
    total=$((total + 1))
    [[ -f $TARGET/$f && ! -L $TARGET/$f ]] && ! cmp -s "$TARGET/$f" "$STOW_DIR/$pkg/$f" && differ+=("$f")
  done < <(conflicts "$pkg")
  (( total )) || return 0
  warn "$pkg: $total existing file(s) would be moved to a backup"
  for f in "${differ[@]}"; do printf '    differs from repo: ~/%s\n' "$f" >&2; done
  return 0
}

command -v stow >/dev/null || { $DEPS && { ensure_yay; sudo pacman -S --needed --noconfirm stow; } || die "stow is required"; }

if $DRY; then
  for p in "${PKGS[@]}"; do
    n=$(stow -n -v --no-folding -d "$STOW_DIR" -t "$TARGET" -R "$p" 2>&1 | grep -c '^LINK:' || true)
    log "dry run: $p ($n new links)"
    report_conflicts "$p"
  done
  exit 0
fi

$DEPS && install_deps
for p in "${PKGS[@]}"; do report_conflicts "$p"; log "linking $p"; link_pkg "$p"; done
$SYSTEM && setup_system

if $CHSH && [[ $(basename "$(getent passwd "$USER" | cut -d: -f7)") != zsh ]]; then
  log "changing login shell to zsh"
  chsh -s "$(command -v zsh)"
fi
if $SYSTEM && command -v pkgfile >/dev/null; then
  quiet "building pkgfile database" sudo pkgfile -u || warn "pkgfile database not built; run: sudo pkgfile -u"
fi

log "done. Log out and back in (groups, shell, env). Backups, if any: $BACKUP"
