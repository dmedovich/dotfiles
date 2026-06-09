#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

GO_OS="${GO_OS:-linux}"
GO_ARCH="${GO_ARCH:-amd64}"
GO_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles"

echo "==> Installing Fedora packages"

sudo dnf install -y \
    zsh \
    neovim \
    dnf-plugins-core \
    git \
    curl \
    jq \
    ca-certificates \
    fontconfig \
    tar \
    unzip \
    fzf \
    fd-find \
    ripgrep \
    tree-sitter-cli \
    make \
    gcc \
    gcc-c++

echo "==> Resolving Go version"

GO_RELEASES_JSON="$(curl -fsSL 'https://go.dev/dl/?mode=json&include=all')"

if [ -n "${GO_VERSION:-}" ]; then
    GO_VERSION="${GO_VERSION#go}"
else
    GO_VERSION="$(printf '%s' "$GO_RELEASES_JSON" \
        | jq -r '[.[] | select(.stable == true)][0].version | ltrimstr("go")')"
fi

GO_RELEASE="go${GO_VERSION}"
GO_ARCHIVE="$(printf '%s' "$GO_RELEASES_JSON" \
    | jq -r --arg version "$GO_RELEASE" --arg os "$GO_OS" --arg arch "$GO_ARCH" \
        '.[] | select(.version == $version) | .files[] | select(.os == $os and .arch == $arch and .kind == "archive") | .filename' \
    | head -n 1)"
GO_SHA256="$(printf '%s' "$GO_RELEASES_JSON" \
    | jq -r --arg filename "$GO_ARCHIVE" \
        '.[] | .files[] | select(.filename == $filename) | .sha256' \
    | head -n 1)"

if [ -z "$GO_ARCHIVE" ] || [ "$GO_ARCHIVE" = "null" ] || [ -z "$GO_SHA256" ] || [ "$GO_SHA256" = "null" ]; then
    echo "Unable to resolve Go archive for $GO_RELEASE $GO_OS/$GO_ARCH" >&2
    exit 1
fi

GO_URL="https://go.dev/dl/${GO_ARCHIVE}"
GO_ARCHIVE_PATH="$GO_CACHE_DIR/$GO_ARCHIVE"

echo "==> Selected $GO_RELEASE for $GO_OS/$GO_ARCH"

echo "==> Installing Ghostty"

if ! command -v ghostty >/dev/null 2>&1; then
    sudo dnf install -y ghostty || {
        sudo dnf copr enable -y scottames/ghostty
        sudo dnf install -y ghostty
    }
fi

echo "==> Installing Zsh plugins"

if [ ! -d "$HOME/.oh-my-zsh" ]; then
    git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

if [ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]; then
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
    "$ZSH_CUSTOM/themes/powerlevel10k"
fi

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git \
    "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
fi

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git \
    "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
fi

echo "==> Creating directories"

mkdir -p ~/.config
mkdir -p ~/.config/ghostty

mkdir -p ~/.local/bin
mkdir -p ~/.local/share/go
mkdir -p ~/.local/share/fonts/mononoki
mkdir -p ~/.cache/go-build
mkdir -p "$GO_CACHE_DIR"

echo "==> Installing configs"

install -m 0644 "$REPO_ROOT/zsh/.zshrc" "$HOME/.zshrc"

install -m 0644 "$REPO_ROOT/ghostty/.config/ghostty/config" \
"$HOME/.config/ghostty/config"

rm -rf ~/.config/nvim

if find "$REPO_ROOT/nvim" -type f ! -name ".gitkeep" | grep -q .; then
    cp -r "$REPO_ROOT/nvim" "$HOME/.config/"
else
    echo "==> Neovim config is empty; using default Neovim"
fi

echo "==> Installing Mononoki font"

unzip -o "$REPO_ROOT/fonts/Mononoki.zip" \
-d "$HOME/.local/share/fonts/mononoki"

fc-cache -fv

echo "==> Installing Go"

if [ ! -f "$GO_ARCHIVE_PATH" ]; then
    curl -fL --retry 3 -o "$GO_ARCHIVE_PATH" "$GO_URL"
fi

echo "$GO_SHA256  $GO_ARCHIVE_PATH" | sha256sum -c -

sudo rm -rf /usr/local/go

sudo tar -C /usr/local -xzf "$GO_ARCHIVE_PATH"

echo "==> Installing Go tools"

export PATH="/usr/local/go/bin:$HOME/.local/bin:$PATH"
export GOBIN="$HOME/.local/bin"

go install golang.org/x/tools/gopls@latest
go install mvdan.cc/gofumpt@latest
go install github.com/go-delve/delve/cmd/dlv@latest
go install github.com/air-verse/air@latest
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest

echo "==> Installing Neovim plugins and tools"

nvim --headless \
    '+lua print("Neovim plugins installed")' \
    +qa

nvim --headless \
    '+lua require("nvim-treesitter").install({ "go", "gomod", "gosum", "gowork", "lua", "luadoc", "query", "vim", "vimdoc", "zig" }):wait(300000); print("Treesitter parsers installed")' \
    +qa

nvim --headless \
    '+MasonInstall lua-language-server gopls zls' \
    '+sleep 30000m' \
    +qa

echo "==> Done"
echo "Restart your shell or run: source ~/.zshrc"
