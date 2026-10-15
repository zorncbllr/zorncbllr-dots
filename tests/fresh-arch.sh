#!/usr/bin/env bash
# Run install.sh end to end on a pristine Arch Linux container (systemd-nspawn).
#
#   sudo ./tests/fresh-arch.sh [--keep]
#
# Needs: root, systemd-nspawn, bsdtar, zstd, curl, ~10 GB free in /var/lib/machines.
# Output is also written to $LOG (default /tmp/dots-fresh-test.log).
# --keep leaves the container in place for poking around:
#   sudo systemd-nspawn -D /var/lib/machines/dots-test -u tester
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "run with sudo" >&2; exit 1; }
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
M="${MACHINE_DIR:-/var/lib/machines/dots-test}"
NAME=dots-test
LOG="${LOG:-/tmp/dots-fresh-test.log}"
KEEP=false; [[ ${1:-} == --keep ]] && KEEP=true
exec > >(tee "$LOG") 2>&1

PASS=0 FAIL=0
step()  { printf '\n=== %s\n' "$*"; }
check() { # check "description" command...
  local d=$1; shift
  if "$@" >/dev/null 2>&1; then printf '  PASS  %s\n' "$d"; PASS=$((PASS+1))
  else printf '  FAIL  %s\n' "$d"; FAIL=$((FAIL+1)); fi
}
nsp()   { systemd-nspawn -q --resolv-conf=off -D "$M" --machine="$NAME" "$@"; }
as_user() { nsp -u tester --chdir=/home/tester/zorncbllr-dots bash -c "$*"; }

cleanup() {
  machinectl terminate "$NAME" 2>/dev/null || true
  $KEEP || { step "removing container"; rm -rf "$M"; }
}
trap cleanup EXIT

step "bootstrap ($M)"
# Mirrors hosting iso/latest; tried in order. The host's own pacman mirror first.
MIRRORS=("$(grep -m1 '^Server' /etc/pacman.d/mirrorlist | sed -E 's/^Server *= *//; s#/\$repo/os/\$arch##')"
         https://mirror.rackspace.com/archlinux https://geo.mirror.pkgbuild.com)
if [[ ! -d $M/usr ]]; then
  mkdir -p "$M"; tmp=$(mktemp -d); got=false
  for mirror in "${MIRRORS[@]}"; do
    echo "trying $mirror"
    if curl -fL --retry 5 --retry-delay 3 --retry-all-errors -o "$tmp/b.tar.zst" "$mirror/iso/latest/archlinux-bootstrap-x86_64.tar.zst" &&
       curl -fL --retry 5 --retry-delay 3 --retry-all-errors -o "$tmp/sums" "$mirror/iso/latest/sha256sums.txt" &&
       awk '$2=="archlinux-bootstrap-x86_64.tar.zst"{print $1"  b.tar.zst"}' "$tmp/sums" > "$tmp/sum" &&
       (cd "$tmp" && sha256sum -c sum); then got=true; break; fi
  done
  $got || { echo "could not download a verified bootstrap tarball from any mirror" >&2; exit 1; }
  bsdtar -xpf "$tmp/b.tar.zst" -C "$M" --strip-components=1 --numeric-owner
  rm -rf "$tmp"
fi
# Reuse the host's mirrorlist: those mirrors are known to work from this network.
cp /etc/pacman.d/mirrorlist "$M/etc/pacman.d/mirrorlist"
# Router resolvers drop lookups under load (many parallel downloads): keep the host's
# first, then public fallbacks, so a flaky LAN resolver does not fail the test.
rm -f "$M/etc/resolv.conf"
{ grep -m2 '^nameserver' /etc/resolv.conf; echo "nameserver 1.1.1.1"; echo "nameserver 9.9.9.9"; } > "$M/etc/resolv.conf"

step "base system + test user"
retry() { local i; for i in 1 2 3 4; do "$@" && return 0; echo "attempt $i failed: $*; retrying in $((i*10))s" >&2; sleep $((i*10)); done; return 1; }
retry nsp bash -c 'pacman-key --init && pacman-key --populate archlinux &&
  pacman -Syu --noconfirm --needed base-devel git sudo'
nsp bash -c '{ id tester >/dev/null 2>&1 || useradd -m -G wheel tester; } &&
  echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel'
rm -rf "$M/home/tester/zorncbllr-dots"
cp -a "$REPO" "$M/home/tester/zorncbllr-dots"
nsp chown -R tester:tester /home/tester/zorncbllr-dots

step "phase 1: ./install.sh --no-system --no-chsh (packages, builds, venv, links)"
as_user './install.sh --no-system --no-chsh'

step "phase 1 checks"
check "yay installed"                      as_user 'command -v yay'
check "zsh + plugins installed"            as_user 'pacman -Q zsh zsh-autosuggestions zsh-syntax-highlighting pkgfile'
check "quickshell + hyprland installed"    as_user 'pacman -Q quickshell hyprland'
check "MicroTeX built and installed"       as_user 'pacman -Q illogical-impulse-microtex-git'
check "cursor theme built and installed"   as_user 'pacman -Q illogical-impulse-bibata-modern-classic-bin'
check "python venv created"                as_user 'test -x ~/.local/state/quickshell/.venv/bin/python'
check "~/.zshrc links into the repo"       as_user 'test "$(readlink ~/.zshrc)" = zorncbllr-dots/stow/zsh/.zshrc'
check "no dangling symlinks"               as_user 'test -z "$(find ~/.config ~/.local/bin -xtype l)"'
check "generated colour files are copies"  as_user 'test -f ~/.config/hypr/hyprland/colors.lua -a ! -L ~/.config/hypr/hyprland/colors.lua'
check "zsh loads .zshrc without errors"    as_user 'zsh -i -c exit 2>&1 | grep -qiE "error|not found" && exit 1 || exit 0'

step "phase 2: second run is a no-op"
as_user './install.sh --no-system --no-chsh' | tee /tmp/second-run.txt
check "second run installs nothing"        grep -q 'already satisfied' /tmp/second-run.txt
check "second run backs up nothing"        bash -c '! grep -q "backing up" /tmp/second-run.txt'

step "phase 3: boot the container, run the system step"
systemd-nspawn -q -b --resolv-conf=off -D "$M" --machine="$NAME" >/dev/null 2>&1 &
for _ in $(seq 60); do machinectl show "$NAME" >/dev/null 2>&1 && break; sleep 1; done
sleep 8
systemd-run -q -M "$NAME" --wait --pipe -p User=tester -p WorkingDirectory=/home/tester/zorncbllr-dots \
  --setenv=HOME=/home/tester --setenv=USER=tester bash -c './install.sh --no-deps --no-chsh' || true
check "i2c group exists"                   systemd-run -q -M "$NAME" --wait --pipe getent group i2c
check "tester is in video,i2c,input"       systemd-run -q -M "$NAME" --wait --pipe bash -c 'id -nG tester | tr " " "\n" | grep -cx -e video -e i2c -e input | grep -qx 3'
check "i2c-dev module config written"      test -f "$M/etc/modules-load.d/i2c-dev.conf"
check "bluetooth service enabled"          systemd-run -q -M "$NAME" --wait --pipe systemctl is-enabled bluetooth

step "result: $PASS passed, $FAIL failed (log: $LOG)"
(( FAIL == 0 ))
