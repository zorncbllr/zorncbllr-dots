# ~/.zshenv
# Sourced by EVERY zsh invocation, including scripts and `zsh -c ...`.
# Keep it minimal and fast. Interactive-only stuff belongs in ~/.zshrc.

# ~/.config/zshrc.d/auto-Hypr.sh tests `[ "$XDG_VTNR" -eq 1 ]`. Without a
# numeric default zsh prints "integer expression expected" on any login where
# logind didn't set it (vs. fish, which just failed the test silently).
export XDG_VTNR="${XDG_VTNR:-0}"