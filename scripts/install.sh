#!/usr/bin/env bash

set -e

echo "==> Installing Fedora packages"

sudo dnf install -y \
    zsh \
    neovim \
    git \
    curl \
    unzip \
    fzf \
    fd-find \
    ripgrep \
    gcc \
    gcc-c++

echo "==> Installing Ghostty"

if ! command -v ghostty >/dev/null 2>&1; then
    sudo dnf install -y ghostty || {
        sudo dnf copr enable -y scottames/ghostty
        sudo dnf install -y ghostty
    }
fi

echo "==> Creating directories"

mkdir -p ~/.config
mkdir -p ~/.config/ghostty
mkdir -p ~/.config/VSCodium/User

mkdir -p ~/.local/bin
mkdir -p ~/.local/share/go
mkdir -p ~/.local/share/fonts/mononoki
mkdir -p ~/.cache/go-build

echo "==> Installing configs"

cp zsh/.zshrc ~/.zshrc

cp ghostty/.config/ghostty/config \
~/.config/ghostty/config

cp vscodium/settings.json \
~/.config/VSCodium/User/settings.json

cp -r nvim ~/.config/

echo "==> Installing Mononoki font"

unzip -o fonts/Mononoki.zip \
-d ~/.local/share/fonts/mononoki

fc-cache -fv

echo "==> Installing Go"

sudo rm -rf /usr/local/go

sudo tar -C /usr/local -xzf \
~/Downloads/go1.26.3.linux-amd64.tar.gz

echo "==> Installing Go tools"

export PATH="/usr/local/go/bin:$HOME/.local/bin:$PATH"

go install golang.org/x/tools/gopls@latest
go install github.com/go-delve/delve/cmd/dlv@latest
go install github.com/air-verse/air@latest
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest

echo "==> Done"
echo "Restart your shell or run: source ~/.zshrc"
