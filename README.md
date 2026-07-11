# dotfiles

Personal Linux dotfiles.

## Contents

- `zsh/.zshrc` - zsh config for Oh My Zsh and powerlevel10k.
- `ghostty/.config/ghostty/config` - Ghostty config.
- `nvim/` - Neovim config.
- `vscodium/settings.json` - VSCodium user settings.
- `fonts/Mononoki.zip` - Mononoki Nerd Font archive.
- `scripts/install.sh` - full Fedora-oriented installer.

## Full install

Run from the repository root:

```sh
./scripts/install.sh
```

The script installs Fedora packages, Ghostty, Oh My Zsh, zsh plugins, powerlevel10k, config files, Mononoki Nerd Font, Go, Go tools, Neovim plugins, Treesitter parsers, and Mason tools.

The script overwrites:

```text
~/.zshrc
~/.config/ghostty/config
~/.config/VSCodium/User/settings.json
~/.config/nvim
```

Go version can be pinned:

```sh
GO_VERSION=1.24.5 ./scripts/install.sh
```

Target Go archive can be changed:

```sh
GO_OS=linux GO_ARCH=amd64 ./scripts/install.sh
```

## Base packages

Fedora:

```sh
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
```

## zsh

Install Oh My Zsh:

```sh
git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git ~/.oh-my-zsh
```

Install theme and plugins:

```sh
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
  "$ZSH_CUSTOM/themes/powerlevel10k"

git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git \
  "$ZSH_CUSTOM/plugins/zsh-autosuggestions"

git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git \
  "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
```

Install config:

```sh
install -m 0644 zsh/.zshrc ~/.zshrc
```

Set login shell:

```sh
chsh -s "$(command -v zsh)"
```

## Ghostty

Install Ghostty:

```sh
sudo dnf install -y ghostty
```

If the package is not available:

```sh
sudo dnf copr enable -y scottames/ghostty
sudo dnf install -y ghostty
```

Install config:

```sh
mkdir -p ~/.config/ghostty
install -m 0644 ghostty/.config/ghostty/config ~/.config/ghostty/config
```

## Neovim

This config requires Neovim 0.12+ with `vim.pack`.

Install config:

```sh
mkdir -p ~/.config
rm -rf ~/.config/nvim
cp -r nvim ~/.config/nvim
```

Install plugins:

```sh
nvim --headless '+lua print("Neovim plugins installed")' +qa
```

Install Treesitter parsers:

```sh
nvim --headless \
  '+lua require("nvim-treesitter").install({ "go", "gomod", "gosum", "gowork", "lua", "luadoc", "query", "vim", "vimdoc", "zig" }):wait(300000)' \
  +qa
```

Install Mason tools:

```sh
nvim --headless \
  '+MasonInstall lua-language-server gopls zls' \
  '+sleep 30000m' \
  +qa
```

## VSCodium

Install settings:

```sh
mkdir -p ~/.config/VSCodium/User
install -m 0644 vscodium/settings.json ~/.config/VSCodium/User/settings.json
```

Settings reference these extensions:

```sh
codium --install-extension Yukina.yukinord
codium --install-extension PKief.material-icon-theme
```

## Font

Install Mononoki Nerd Font:

```sh
mkdir -p ~/.local/share/fonts/mononoki
unzip -o fonts/Mononoki.zip -d ~/.local/share/fonts/mononoki
fc-cache -fv
```

Check fontconfig:

```sh
fc-match 'Mononoki Nerd Font'
```

## Go

The full installer downloads the latest stable Go archive for `GO_OS` and `GO_ARCH`, verifies SHA256 from `https://go.dev/dl/?mode=json&include=all`, and installs it to `/usr/local/go`.

Manual install path expected by `.zshrc`:

```text
/usr/local/go
```

Install Go tools:

```sh
export PATH="/usr/local/go/bin:$HOME/.local/bin:$PATH"
export GOBIN="$HOME/.local/bin"

go install golang.org/x/tools/gopls@latest
go install mvdan.cc/gofumpt@latest
go install github.com/go-delve/delve/cmd/dlv@latest
go install github.com/air-verse/air@latest
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
```

## Sync checks

Compare repository Neovim config with the active config:

```sh
diff -qr nvim ~/.config/nvim
```

Check which config Neovim uses:

```sh
nvim --headless +'lua print(vim.fn.stdpath("config"))' +qa
```

Compare VSCodium settings:

```sh
diff -u vscodium/settings.json ~/.config/VSCodium/User/settings.json
```

Compare zsh config:

```sh
diff -u zsh/.zshrc ~/.zshrc
```
