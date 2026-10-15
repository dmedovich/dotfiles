#!/usr/bin/env bash
# Update an existing installation without rerunning the full Fedora installer.
set -Eeuo pipefail
REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
[[ $# == 0 ]] || { echo 'Usage: bash scripts/update-dev.sh' >&2; exit 1; }
export PATH="/usr/local/go/bin:$HOME/.local/bin:$PATH"
for command in git zsh fzf fd zoxide python3 go nvim ghostty; do
    command -v "$command" >/dev/null || { echo "Missing $command; see the Developer workflow section in README." >&2; exit 1; }
done
export GOBIN="$HOME/.local/bin"
export GOTOOLCHAIN=local
zsh -n "$REPO_ROOT/zsh/.zshrc"
NVIM_LOG_FILE=/dev/null nvim --clean --headless -l "$REPO_ROOT/scripts/check-neovim.lua" "$REPO_ROOT"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
mkdir -p "$state_home/dotfiles-dev-backups" "$GOBIN"
backup="$(mktemp -d "$state_home/dotfiles-dev-backups/update-XXXXXXXX")"
chmod 700 "$backup"
for target in "$HOME/.zshrc" "$config_home/nvim" "$config_home/ghostty/config" "$GOBIN/dotfiles-check" "$GOBIN/dlv" "$GOBIN/gitleaks"; do
    if [[ -e "$target" || -L "$target" ]]; then
        destination="$backup/${target#/}"
        mkdir -p "$(dirname -- "$destination")"
        cp -a -- "$target" "$destination"
    fi
done
printf 'Backups: %s\n' "$backup"
go install github.com/go-delve/delve/cmd/dlv@latest
go install github.com/zricethezav/gitleaks/v8@latest
# Copy tools/configs only after prerequisites and Go builds succeed.
install -m 0755 "$REPO_ROOT/scripts/dotfiles-check" "$GOBIN/dotfiles-check"
install -m 0644 "$REPO_ROOT/zsh/.zshrc" "$HOME/.zshrc"
mkdir -p "$config_home/nvim" "$config_home/ghostty"
cp -R "$REPO_ROOT/nvim/." "$config_home/nvim/"
install -m 0644 "$REPO_ROOT/ghostty/.config/ghostty/config" "$config_home/ghostty/config"
DOTFILES_NVIM_INIT="$config_home/nvim/init.lua" timeout --foreground 20m nvim --headless -u NONE -i NONE -l "$REPO_ROOT/scripts/bootstrap-nvim.lua"
ghostty +validate-config
printf 'Updated. Restart zsh, Neovim and Ghostty. Enable checks per project: dotfiles-check install\n'
