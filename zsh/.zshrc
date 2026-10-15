if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="powerlevel10k/powerlevel10k"

#plugins
plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

# Better history
HISTSIZE=100000
SAVEHIST=100000
HISTFILE=~/.zsh_history

setopt HIST_IGNORE_DUPS
setopt SHARE_HISTORY
setopt HIST_SAVE_NO_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_IGNORE_SPACE
setopt EXTENDED_HISTORY

# Vim mode
bindkey -v

#some alias
alias ll="ls -la"
alias gs="git status"
alias gc="git commit"

export PATH="/usr/local/go/bin:$HOME/.local/bin:$PATH"
export GOPATH="$HOME/.local/share/go"
export GOBIN="$HOME/.local/bin"
export GOCACHE="$HOME/.cache/go-build"

# Ctrl-R searches history; Ctrl-T selects files; Alt-C selects directories.
if (( $+commands[fzf] )); then
  if fzf --zsh >/dev/null 2>&1; then
    source <(fzf --zsh)
  else
    for _fzf_bindings in /usr/share/fzf/shell/key-bindings.zsh /usr/share/fzf/key-bindings.zsh; do
      if [[ -r "$_fzf_bindings" ]]; then
        source "$_fzf_bindings"
        break
      fi
    done
    unset _fzf_bindings
  fi
fi

# z remembers visited directories; zi selects one interactively.
if (( $+commands[zoxide] )); then
  eval "$(zoxide init zsh)"
fi

# Override this array in ~/.zshrc.local to use different repository roots.
typeset -ga PROJECT_DIRS
PROJECT_DIRS=("$HOME/Work" "$HOME/Projects" "$HOME/projects" "$HOME/src" "$HOME/dotfiles")

p() {
  if ! (( $+commands[fd] && $+commands[fzf] )); then
    print -u2 'p requires fd and fzf.'
    return 1
  fi
  local entry selected
  local -a roots
  for entry in "${PROJECT_DIRS[@]}"; do
    [[ ! -d "$entry" ]] || roots+=("$entry")
  done
  (( ${#roots} )) || { print -u2 'No project roots found; set PROJECT_DIRS in ~/.zshrc.local.'; return 1; }
  selected=$(
    fd --hidden --no-ignore --max-depth 6 --exclude node_modules --exclude vendor \
      --exclude .cache --exclude objects --print0 '^\.git$' "${roots[@]}" |
      while IFS= read -r -d '' entry; do
        entry=${entry%/}
        print -r -- "${entry:h}"
      done | sort -u | fzf --height=60% --layout=reverse --prompt='Project> ' --query="$*"
  ) || return
  [[ -z "$selected" ]] || builtin cd -- "$selected"
}

croot() {
  local root
  root=$(git rev-parse --show-toplevel 2>/dev/null) || return
  builtin cd -- "$root"
}

[[ ! -r ~/.zshrc.local ]] || source ~/.zshrc.local

[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
