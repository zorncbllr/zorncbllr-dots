# ~/.zshrc — interactive zsh (plain Arch plugin packages, no oh-my-zsh)

# --- Hyprland on tty1 (must stay first: it execs) -----------------------------
[[ -r $HOME/.config/zshrc.d/auto-Hypr.sh ]] && source $HOME/.config/zshrc.d/auto-Hypr.sh

# --- Options ------------------------------------------------------------------
setopt AUTO_CD AUTO_PUSHD PUSHD_IGNORE_DUPS PUSHD_SILENT
setopt INTERACTIVE_COMMENTS AUTO_PARAM_KEYS EXTENDED_GLOB
setopt NO_BEEP NO_FLOW_CONTROL        # NO_FLOW_CONTROL frees Ctrl+S / Ctrl+Q

# --- History ------------------------------------------------------------------
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY HIST_IGNORE_ALL_DUPS HIST_SAVE_NO_DUPS HIST_REDUCE_BLANKS
setopt HIST_EXPIRE_DUPS_FIRST HIST_FIND_NO_DUPS

# --- PATH ---------------------------------------------------------------------
typeset -U path
path=("$HOME/.local/bin" $path)

# --- Completion ---------------------------------------------------------------
[[ -d /usr/share/zsh/site-functions ]] && fpath=(/usr/share/zsh/site-functions $fpath)
autoload -Uz compinit && compinit -d "${XDG_CACHE_HOME:-$HOME/.cache}/zcompdump"
setopt AUTO_MENU COMPLETE_IN_WORD
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list \
  'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=*' 'r:/*=/*' 'l:/*=/*'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format ' %F{yellow}-- %d --%f'

# --- Key bindings (terminfo-based, replaces what oh-my-zsh used to set) -------
bindkey -e
typeset -A key=(
  Home      "${terminfo[khome]}"  End    "${terminfo[kend]}"
  Delete    "${terminfo[kdch1]}"  Up     "${terminfo[kcuu1]}"
  Down      "${terminfo[kcud1]}"  Insert "${terminfo[kich1]}"
)
[[ -n $key[Home]   ]] && bindkey -- "$key[Home]"   beginning-of-line
[[ -n $key[End]    ]] && bindkey -- "$key[End]"    end-of-line
[[ -n $key[Delete] ]] && bindkey -- "$key[Delete]" delete-char
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
[[ -n $key[Up]   ]] && bindkey -- "$key[Up]"   up-line-or-beginning-search
[[ -n $key[Down] ]] && bindkey -- "$key[Down]" down-line-or-beginning-search

# --- Dotfiles snippets (colour scheme, extra keybindings) ---------------------
for _f in $HOME/.config/zshrc.d/*.zsh(N); do source "$_f"; done
unset _f

# --- Plugins (Arch packages; syntax-highlighting must be sourced last) --------
_p=/usr/share/zsh/plugins
[[ -r $_p/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && source $_p/zsh-autosuggestions/zsh-autosuggestions.zsh
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
# "command not found" suggestions (pkgfile -u once to build the database)
[[ -r /usr/share/doc/pkgfile/command-not-found.zsh ]] && source /usr/share/doc/pkgfile/command-not-found.zsh

# --- Greeting -----------------------------------------------------------------
(( $+commands[fastfetch] )) && fastfetch

# --- Prompt (starship, config in ~/.config/starship.toml) ---------------------
if [[ "$TERM" != "linux"* ]] && (( $+commands[starship] )); then
  eval "$(starship init zsh)"
  # Seed the clock so the first prompt also shows the duration pill.
  if (( $+functions[__starship_get_time] )); then
    __starship_get_time && typeset -g STARSHIP_START_TIME=$STARSHIP_CAPTURED_TIME
  fi
fi

# --- Aliases ------------------------------------------------------------------
# kitty needs the explicit escape sequence to clear scrollback too
alias clear="printf '\033[2J\033[3J\033[1;1H'"
alias celar=clear claer=clear
alias q='qs -c ii'
if [[ "$TERM" != "linux"* ]] && (( $+commands[eza] )); then alias ls='eza --icons=auto'; fi
[[ "$TERM" == "xterm-kitty" ]] && alias ssh='kitten ssh'

# --- Personal overrides (not tracked): aliases, functions, PATH ---------------
[[ -r $HOME/.zshrc.local ]] && source $HOME/.zshrc.local

# --- Syntax highlighting (must come last) -------------------------------------
[[ -r $_p/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && source $_p/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
unset _p
