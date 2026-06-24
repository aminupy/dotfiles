# ------------------------------
# Profiling (only when requested)
# ------------------------------
if [[ -n "$ZSH_PROFILE" ]]; then
  zmodload zsh/zprof
fi

# ------------------------------
# Responsiveness (important for tmux/vim)
# ------------------------------
KEYTIMEOUT=1

# ------------------------------
# PATH (do this once, cleanly)
# ------------------------------
typeset -U path PATH
path=(
  "$HOME/.gapcode/bin"
  "$HOME/.local/bin"
  "$HOME/Scripts"
  "$HOME/.volta/bin"
  /usr/local/go/bin
  "$HOME/.go/bin"
  "$HOME/.local/kitty.app/bin"
  /opt/nvim-linux-x86_64/bin
  "$HOME/go/bin"
$path
)
export PATH

# ------------------------------
# Completion (robust + fast)
# ------------------------------
autoload -Uz compinit

zcompdump="$HOME/.zcompdump"
if [[ -f "$zcompdump" ]] && find "$zcompdump" -mtime -1 >/dev/null 2>&1; then
  compinit -C
else
  compinit
fi

zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

# ------------------------------
# History (persistent + pro)
# ------------------------------
HISTFILE="$HOME/.zsh_history"
HISTSIZE=20000
SAVEHIST=20000

setopt append_history
setopt inc_append_history
setopt share_history
setopt hist_ignore_dups
setopt hist_reduce_blanks
setopt hist_verify
setopt hist_fcntl_lock

# ------------------------------
# Prompt (fast, OMZ-like ➜ ~)
# ------------------------------
autoload -Uz colors && colors
setopt prompt_subst
PROMPT='%F{green}➜%f %F{yellow}%~%f '
RPROMPT=''

# ------------------------------
# Tools
# ------------------------------
eval "$(zoxide init zsh)"
eval "$(uv generate-shell-completion zsh 2>/dev/null)" || true
export VOLTA_HOME="$HOME/.volta"

# ------------------------------
# Plugins
# ------------------------------
if [[ -o interactive ]]; then
  source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
  source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# ------------------------------
# Aliases
# ------------------------------
alias ls="lsd -l --group-dirs=first"
alias ll="lsd -la --group-dirs=first"
alias ..="cd .."
alias ...="cd ../.."
alias vim="nvim"
alias nv="nvim"
alias chrome="google-chrome-stable --ozone-platform-hint=auto"
alias reload="exec zsh"

# ------------------------------
# Environment
# ------------------------------
export _JAVA_AWT_WM_NONREPARENTING=1
export SKIKO_RENDER_API=SOFTWARE

# ------------------------------
# Secrets
# ------------------------------
[[ -r "$HOME/.config/secrets/env.zsh" ]] && source "$HOME/.config/secrets/env.zsh"

# ------------------------------
# Profiling output
# ------------------------------
if [[ -n "$ZSH_PROFILE" ]]; then
  zprof
fi

. "$HOME/.cargo/env"

# ------------------------------
# Key Bindings
# ------------------------------
# Fix Ctrl+Left/Right to move by word
bindkey "^[[1;5C" forward-word
bindkey "^[[1;5D" backward-word

# Fix Home/End keys (often broken in Alacritty/Zsh)
bindkey "^[[H" beginning-of-line
bindkey "^[[F" end-of-line

fpath+=${ZDOTDIR:-~}/.zsh_functions

setopt interactive_comments


alias pbpaste='xclip -selection clipboard -o'
alias pbcopy='xclip -selection clipboard'


alias history='history 1'
alias h='history 1 | grep'
