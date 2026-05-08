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
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history

setopt HIST_IGNORE_DUPS
setopt SHARE_HISTORY

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

[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
