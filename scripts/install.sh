#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

GO_VERSION="${GO_VERSION:-1.26.3}"
GO_ARCHIVE="go${GO_VERSION}.linux-amd64.tar.gz"
GO_URL="https://go.dev/dl/${GO_ARCHIVE}"
GO_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles"
GO_ARCHIVE_PATH="$GO_CACHE_DIR/$GO_ARCHIVE"

echo "==> Installing Fedora packages"

sudo dnf install -y \
    zsh \
    neovim \
    git \
    curl \
    ca-certificates \
    fontconfig \
    tar \
    unzip \
    fzf \
    fd-find \
    ripgrep \
    make \
    gcc \
    gcc-c++

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

if [ "$GO_VERSION" = "1.26.3" ]; then
    echo "2b2cfc7148493da5e73981bffbf3353af381d5f93e789c82c79aff64962eb556  $GO_ARCHIVE_PATH" \
    | sha256sum -c -
fi

sudo rm -rf /usr/local/go

sudo tar -C /usr/local -xzf "$GO_ARCHIVE_PATH"

echo "==> Installing Go tools"

export PATH="/usr/local/go/bin:$HOME/.local/bin:$PATH"
export GOBIN="$HOME/.local/bin"

go install golang.org/x/tools/gopls@latest
go install github.com/go-delve/delve/cmd/dlv@latest
go install github.com/air-verse/air@latest
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest

echo "==> Done"
echo "Restart your shell or run: source ~/.zshrc"
