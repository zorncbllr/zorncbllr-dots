# Use the generated color scheme

_seq=~/.local/state/quickshell/user/generated/terminal/sequences.txt
if [[ -f $_seq ]]; then
    cat "$_seq"
    # The generator's template can end its last OSC with a bare ESC (no "\").
    # Unterminated, the terminal swallows everything printed next (fastfetch).
    [[ "$(tail -c1 "$_seq" | od -An -tx1 | tr -d ' ')" == 1b ]] && printf '\\'
fi
unset _seq
