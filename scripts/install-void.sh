#!/usr/bin/env bash
# Void Linux installer for these dotfiles.
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib/git.sh
source "$SCRIPT_DIR/lib/git.sh"

log()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

[[ -r /etc/os-release ]] || die "Cannot detect the operating system."
# shellcheck disable=SC1091
. /etc/os-release
[[ "${ID:-}" == "void" ]] || die "This installer is for Void Linux (detected: ${ID:-unknown})."
command -v xbps-install >/dev/null 2>&1 || die "xbps-install is not available."
command -v sudo >/dev/null 2>&1 || die "sudo is required."
[[ -z "${GIT_CONFIG_GLOBAL:-}" || "$GIT_CONFIG_GLOBAL" == "$HOME/.gitconfig" ]] || die 'Unset custom GIT_CONFIG_GLOBAL before installation.'

BACKUP_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles-backups/$(date +%Y%m%d-%H%M%S)"
backup_file() {
    local src="$1"
    [[ -e "$src" || -L "$src" ]] || return 0
    mkdir -p "$BACKUP_ROOT"
    local rel="${src#$HOME/}"
    local dst="$BACKUP_ROOT/$rel"
    mkdir -p "$(dirname "$dst")"
    mv -- "$src" "$dst"
    log "Backed up $src -> $dst"
}

log "Installing Void Linux packages"
sudo xbps-install -S \
    zsh \
    neovim \
    git \
    curl \
    jq \
    ca-certificates \
    fontconfig \
    tar \
    unzip \
    fzf \
    fd \
    ripgrep \
    tree-sitter-cli \
    make \
    gcc \
    go

log "Installing Ghostty"
if ! command -v ghostty >/dev/null 2>&1; then
    if sudo xbps-install -S ghostty; then
        :
    else
        warn "Ghostty is not available from the enabled Void repositories. Skipping it."
        warn "The Ghostty config will still be installed."
    fi
fi

log "Installing Oh My Zsh and plugins"
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
mkdir -p "$ZSH_CUSTOM/themes" "$ZSH_CUSTOM/plugins"

[[ -d "$ZSH_CUSTOM/themes/powerlevel10k" ]] ||
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
        "$ZSH_CUSTOM/themes/powerlevel10k"

[[ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]] ||
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git \
        "$ZSH_CUSTOM/plugins/zsh-autosuggestions"

[[ -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]] ||
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git \
        "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

log "Creating directories"
mkdir -p \
    "$HOME/.config/ghostty" \
    "$HOME/.config/VSCodium/User" \
    "$HOME/.local/share/fonts/mononoki" \
    "$HOME/.local/bin" \
    "$HOME/.local/share/go" \
    "$HOME/.cache/go-build"

log "Backing up existing configs"
backup_file "$HOME/.zshrc"
backup_file "$HOME/.p10k.zsh"
backup_file "$HOME/.config/ghostty/config"
backup_file "$HOME/.config/VSCodium/User/settings.json"
backup_file "$HOME/.config/nvim"

log "Installing configs"
install_git_defaults "$REPO_ROOT/git/.gitconfig" "${XDG_CONFIG_HOME:-$HOME/.config}/git/dotfiles.gitconfig" \
    "$HOME/.gitconfig" "$HOME/.gitconfig.local" backup_file
install -m 0644 "$REPO_ROOT/zsh/.zshrc" "$HOME/.zshrc"
install -m 0644 "$REPO_ROOT/zsh/.p10k.zsh" "$HOME/.p10k.zsh"
install -m 0644 "$REPO_ROOT/ghostty/.config/ghostty/config" \
    "$HOME/.config/ghostty/config"
install -m 0644 "$REPO_ROOT/vscodium/settings.json" \
    "$HOME/.config/VSCodium/User/settings.json"
cp -a "$REPO_ROOT/nvim" "$HOME/.config/nvim"

log "Installing Mononoki Nerd Font"
unzip -o "$REPO_ROOT/fonts/Mononoki.zip" \
    -d "$HOME/.local/share/fonts/mononoki" >/dev/null
fc-cache -f >/dev/null 2>&1 || true

log "Installing Go tools"
export PATH="/usr/bin:$HOME/.local/bin:$PATH"
export GOPATH="$HOME/.local/share/go"
export GOBIN="$HOME/.local/bin"
export GOCACHE="$HOME/.cache/go-build"

go version
go install golang.org/x/tools/gopls@latest
go install mvdan.cc/gofumpt@latest
go install github.com/go-delve/delve/cmd/dlv@latest
go install github.com/air-verse/air@latest
go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@latest

log "Checking Neovim"
NVIM_VERSION="$(nvim --clean --headless '+lua print(vim.version().major .. "." .. vim.version().minor .. "." .. vim.version().patch)' +qa 2>/dev/null | tail -n1 || true)"
if [[ -z "$NVIM_VERSION" ]]; then
    die "Neovim could not be started."
fi
log "Neovim version: $NVIM_VERSION (config requires 0.12+)"

if ! nvim --clean --headless '+lua assert(vim.fn.has("nvim-0.12") == 1, "Neovim 0.12+ is required")' +qa; then
    die "Installed Neovim is older than 0.12. Update Void and/or use a repository providing Neovim 0.12+."
fi

log "Installing Neovim plugins"
nvim --headless '+lua print("Neovim plugins installed")' +qa

log "Installing Treesitter parsers"
nvim --headless \
    '+lua require("nvim-treesitter").install({ "go", "gomod", "gosum", "gowork", "lua", "luadoc", "query", "vim", "vimdoc", "zig" }):wait(300000); print("Treesitter parsers installed")' \
    +qa

log "Installing Mason language servers"
nvim --headless \
    '+MasonInstall lua-language-server gopls zls' \
    +sleep 30 \
    +qa

if command -v chsh >/dev/null 2>&1; then
    CURRENT_SHELL="$(getent passwd "$USER" | cut -d: -f7 || true)"
    ZSH_PATH="$(command -v zsh)"
    if [[ "$CURRENT_SHELL" != "$ZSH_PATH" ]]; then
        log "Changing login shell to $ZSH_PATH"
        chsh -s "$ZSH_PATH"
    fi
fi

cat <<EOF

Done.

Configs installed:
  ~/.gitconfig (shared defaults and existing preferences)
  ~/.zshrc
  ~/.p10k.zsh
  ~/.config/ghostty/config
  ~/.config/VSCodium/User/settings.json
  ~/.config/nvim

Backups:
  ${BACKUP_ROOT:-none}

Go:
  $(go version)

Restart your shell (or log in again) to use zsh.
EOF
