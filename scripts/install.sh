#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib/fedora.sh
source "$SCRIPT_DIR/lib/fedora.sh"
# shellcheck source=lib/git.sh
source "$SCRIPT_DIR/lib/git.sh"

finish_installation() {
    export PATH="/usr/local/go/bin:$HOME/.local/bin:$PATH"
    export GOBIN="$HOME/.local/bin"
    export GOPATH="$STATE/work/gopath"
    export GOCACHE="$STATE/work/go-build"
    export GOTOOLCHAIN=local
    export NVIM_APPNAME=nvim
    export DOTFILES_NVIM_INIT="$CONFIG_HOME/nvim/init.lua"
    step 'Installing and checking Neovim plugins, parsers and language servers'
    timeout --foreground 20m nvim --headless -u NONE -i NONE --cmd 'set loadplugins' -l "$SCRIPT_DIR/bootstrap-nvim.lua"
    step 'Validating application configs'
    command -v codium >/dev/null || warn 'VSCodium and its extensions are not installed; only its settings were copied. See README.'
    zsh -n "$HOME/.zshrc"
    zsh -n "$HOME/.p10k.zsh"
    ghostty +validate-config

    step 'Making zsh the login shell'
    make_zsh_default

    step 'Finishing installation'
    if [[ -d "$STATE/work" ]]; then
        chmod -R u+w "$STATE/work"
        rm -rf -- "$STATE/work"
    fi
    printf 'complete\n' > "$STATE/status"
    log "Done. Backups and installation journal: $STATE"
    log 'Log out and log in again to start using zsh.'
}

if [[ "${1:-}" == --help ]]; then
    echo 'Usage: bash scripts/install.sh [--check | --resume]'
    echo '  --check  Check prerequisites without installing or changing anything.'
    echo '  --resume Finish an installation that reached the Neovim setup stage.'
    exit 0
fi
[[ $# == 0 || ( $# == 1 && ( $1 == --check || $1 == --resume ) ) ]] || die 'Unknown argument; use --help.'
check_host
check_layout
[[ -z "${GIT_CONFIG_GLOBAL:-}" || "$GIT_CONFIG_GLOBAL" == "$HOME/.gitconfig" ]] || die 'Unset custom GIT_CONFIG_GLOBAL before installation; Git defaults are installed through ~/.gitconfig.'
if [[ "${1:-}" != --check ]]; then
    start_install_logging
    step 'Checking prerequisites'
fi

case "$(uname -m)" in
    x86_64) HOST_GO_ARCH=amd64 ;;
    aarch64) HOST_GO_ARCH=arm64 ;;
    *) die 'Only x86_64 and aarch64 are supported.' ;;
esac
GO_ARCH="${GO_ARCH:-$HOST_GO_ARCH}"
GO_OS="${GO_OS:-linux}"
[[ "$GO_ARCH" == "$HOST_GO_ARCH" && "$GO_OS" == linux ]] || die 'Go must match the host OS and architecture.'
if [[ -n "${GO_VERSION:-}" ]]; then
    [[ "${GO_VERSION#go}" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] || die 'Invalid GO_VERSION.'
fi
for file in git/.gitconfig zsh/.zshrc zsh/.p10k.zsh ghostty/.config/ghostty/config vscodium/settings.json fonts/Mononoki.zip nvim/init.lua scripts/bootstrap-nvim.lua scripts/check-neovim.lua; do
    [[ -s "$REPO_ROOT/$file" ]] || die "Missing or empty repository file: $file"
done
[[ -d "$REPO_ROOT/nvim/lua" ]] || die 'Missing Neovim modules.'
if [[ "${1:-}" == --resume ]]; then
    [[ -d "$STATE" && ! -L "$STATE" ]] || die 'No recorded installation to resume.'
    sudo -v
    lock_state
    [[ "$(cat "$STATE/format")" == 1 && "$(cat "$STATE/user")" == "$USER_NAME" && "$(cat "$STATE/home")" == "$HOME" ]] || die 'Installation journal belongs to another user or format.'
    case "$(cat "$STATE/status")" in
        failed|installing) ;;
        *) die 'Only an unfinished installation can be resumed.' ;;
    esac
    [[ -f "$STATE/go-installing" && ! -f "$STATE/go-restored" ]] || die 'Installation has not reached Neovim setup, or cleanup has started.'
    shopt -s nullglob
    for entry in "$STATE"/paths/*; do
        [[ -f "$entry/ready" && ! -f "$entry/restored" ]] || die 'Incomplete backup or cleanup detected; finish cleanup before reinstalling.'
    done
    if [[ -f "$STATE/checkpoint" ]]; then
        [[ "$(cat "$STATE/checkpoint")" == neovim ]] || die 'Unsupported installation checkpoint.'
    else
        # Compatibility with installations recorded before --resume was added.
        previous_log="$(cat "$STATE/log-file")"
        validate_path "$previous_log"
        [[ "$previous_log" == "$STATE_ROOT/logs/"* ]] || die 'Invalid previous installation log path.'
        grep -Fq '==> Installing and checking Neovim plugins, parsers and language servers' "$previous_log" || die 'Previous installation did not reach Neovim setup.'
    fi
    [[ -s "$CONFIG_HOME/nvim/init.lua" ]] || die 'Installed Neovim config is missing.'
    check_neovim
    INSTALL_STATE_CREATED=true
    printf '%s\n' "$INSTALL_LOG_FILE" > "$STATE/log-file"
    printf 'neovim\n' > "$STATE/checkpoint"
    printf 'installing\n' > "$STATE/status"
    finish_installation
    exit 0
fi
[[ ! -e "$STATE" ]] || die "An installation is already recorded in $STATE. Run scripts/uninstall.sh first (also after a failed install)."
check_space "$HOME" 2097152
check_space /usr/local 524288

if [[ "${1:-}" == --check ]]; then
    if command -v nvim >/dev/null; then
        check_neovim
    else
        warn 'Neovim is not installed; its version will be checked after dnf install.'
    fi
    command -v codium >/dev/null || warn 'VSCodium is not installed; this installer only supplies its settings.'
    log 'Local prerequisites OK. Repository availability, sudo and downloads are checked during installation.'
    exit 0
fi

step 'Checking sudo access'
sudo -v
lock_state
[[ ! -e "$STATE" ]] || die 'Another installation has already created state.'
step 'Initializing installation journal'
mkdir -m 700 "$STATE"
INSTALL_STATE_CREATED=true
printf '%s\n' "$USER_NAME" > "$STATE/user"
printf '%s\n' "$HOME" > "$STATE/home"
printf '1\n' > "$STATE/format"
printf 'installing\n' > "$STATE/status"
mkdir "$STATE/paths" "$STATE/work"
printf '%s\n' "$INSTALL_LOG_FILE" > "$STATE/log-file"
snapshot_packages > "$STATE/packages.before"

step 'Installing Fedora packages'
install_packages zsh neovim dnf-plugins-core git curl jq ca-certificates fontconfig \
    tar unzip fzf fd-find ripgrep tree-sitter-cli make gcc gcc-c++ util-linux-user
step 'Checking installed commands and repository configs'
for cmd in zsh nvim git curl jq fc-cache fc-match tar unzip fzf fd rg tree-sitter make gcc g++ chsh sha256sum timeout; do
    command -v "$cmd" >/dev/null || die "Required command is missing after installation: $cmd"
done
check_neovim
ZSH_PATH="$(command -v zsh)"
grep -Fxq "$ZSH_PATH" /etc/shells || die "$ZSH_PATH is not listed in /etc/shells."
zsh -n "$REPO_ROOT/zsh/.zshrc"
zsh -n "$REPO_ROOT/zsh/.p10k.zsh"
git config --no-includes --file "$REPO_ROOT/git/.gitconfig" --list >/dev/null
if [[ -e "$HOME/.gitconfig" || -L "$HOME/.gitconfig" ]]; then
    git config --no-includes --file "$HOME/.gitconfig" --list >/dev/null
fi
jq -e 'type == "object"' "$REPO_ROOT/vscodium/settings.json" >/dev/null
unzip -tq "$REPO_ROOT/fonts/Mononoki.zip"
step 'Checking network access'
for url in https://github.com https://go.dev/dl/ https://api.github.com/repos/mason-org/mason-registry/releases/latest; do
    curl -fsSL --connect-timeout 15 --max-time 60 --retry 2 -o /dev/null "$url"
done

step 'Resolving and verifying Go'
curl -fsSL --connect-timeout 15 --max-time 120 --retry 3 \
    'https://go.dev/dl/?mode=json&include=all' -o "$STATE/work/go-releases.json"
if [[ -n "${GO_VERSION:-}" ]]; then
    GO_VERSION="${GO_VERSION#go}"
else
    GO_VERSION="$(jq -er '[.[] | select(.stable == true)][0].version | ltrimstr("go")' "$STATE/work/go-releases.json")"
fi
[[ "$GO_VERSION" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] || die 'GO_VERSION must be a stable release, such as 1.24.5.'
GO_FILE="$(jq -ce --arg version "go$GO_VERSION" --arg arch "$GO_ARCH" \
    '[.[] | select(.version == $version) | .files[] | select(.os == "linux" and .arch == $arch and .kind == "archive")][0] // error("Go release not found")' \
    "$STATE/work/go-releases.json")"
GO_ARCHIVE="$(jq -er .filename <<< "$GO_FILE")"
GO_SHA256="$(jq -er .sha256 <<< "$GO_FILE")"
[[ "$GO_ARCHIVE" == "go$GO_VERSION.linux-$GO_ARCH.tar.gz" && "$GO_SHA256" =~ ^[a-f0-9]{64}$ ]] || die 'Invalid Go archive metadata.'
curl -fL --connect-timeout 15 --max-time 900 --retry 3 \
    "https://go.dev/dl/$GO_ARCHIVE" -o "$STATE/work/$GO_ARCHIVE"
printf '%s  %s\n' "$GO_SHA256" "$STATE/work/$GO_ARCHIVE" | sha256sum -c -
tar -xzf "$STATE/work/$GO_ARCHIVE" -C "$STATE/work"
[[ "$("$STATE/work/go/bin/go" version)" == "go version go$GO_VERSION linux/$GO_ARCH" ]] || die 'Downloaded Go does not run correctly.'

step 'Installing Ghostty'
if ! command -v ghostty >/dev/null; then
    if ! install_packages ghostty; then
        COPR_FILE=/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:scottames:ghostty.repo
        if [[ -e "$COPR_FILE" ]]; then
            die 'Ghostty installation failed with an existing COPR configuration; inspect dnf output.'
        fi
        # Record intent before enabling, so cleanup also works if enabling fails.
        touch "$STATE/ghostty-copr"
        sudo dnf copr enable -y scottames/ghostty
        install_packages ghostty
    fi
fi
ghostty --version

step 'Installing Oh My Zsh and plugins'
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
clone_missing https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
[[ -r "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]] || die 'Existing Oh My Zsh directory is incomplete.'
clone_missing https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"
clone_missing https://github.com/zsh-users/zsh-autosuggestions.git "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
clone_missing https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
for file in themes/powerlevel10k/powerlevel10k.zsh-theme plugins/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh; do
    [[ -r "$ZSH_CUSTOM/$file" ]] || die "Incomplete zsh component: $ZSH_CUSTOM/$file"
done

step 'Backing up and installing user configs'
install_git_defaults "$REPO_ROOT/git/.gitconfig" "$CONFIG_HOME/git/dotfiles.gitconfig" \
    "$HOME/.gitconfig" "$HOME/.gitconfig.local" backup_path
replace_file "$REPO_ROOT/zsh/.zshrc" "$HOME/.zshrc"
replace_file "$REPO_ROOT/zsh/.p10k.zsh" "$HOME/.p10k.zsh"
if [[ "$ZSH_CUSTOM" != "$HOME/.oh-my-zsh/custom" ]]; then
    printf 'export ZSH_CUSTOM=%q\n' "$ZSH_CUSTOM" > "$STATE/work/zsh-custom"
    cat "$STATE/work/zsh-custom" "$HOME/.zshrc" > "$STATE/work/zshrc"
    install -m 0644 "$STATE/work/zshrc" "$HOME/.zshrc"
fi
# Newer Ghostty versions prefer config.ghostty; preserve it so it cannot shadow our config.
backup_path "$CONFIG_HOME/ghostty/config.ghostty" preserve
replace_file "$REPO_ROOT/ghostty/.config/ghostty/config" "$CONFIG_HOME/ghostty/config"
replace_file "$REPO_ROOT/vscodium/settings.json" "$CONFIG_HOME/VSCodium/User/settings.json"
backup_path "$CONFIG_HOME/nvim" preserve
mkdir -p "$CONFIG_HOME"
cp -a "$REPO_ROOT/nvim" "$CONFIG_HOME/nvim"
# Isolate this installation from existing plugins, Mason packages and editor state.
for path in "$DATA_HOME/nvim" "$CACHE_HOME/nvim" "$STATE_HOME/nvim"; do
    backup_path "$path"
done
step 'Installing Mononoki Nerd Font'
backup_path "$DATA_HOME/fonts/mononoki"
mkdir -p "$DATA_HOME/fonts/mononoki"
unzip -oq "$REPO_ROOT/fonts/Mononoki.zip" -d "$DATA_HOME/fonts/mononoki"
fc-cache -f
fc-match -f '%{family}\n' 'Mononoki Nerd Font' | grep -qi mononoki || die 'Mononoki Nerd Font was not detected.'

step "Installing Go $GO_VERSION (preserving any previous /usr/local/go)"
GO_BACKUP="/usr/local/.dotfiles-go-$UID-$(date +%Y%m%d%H%M%S)-$$"
printf '%s\n' "$GO_BACKUP" > "$STATE/go-backup"
if [[ -e /usr/local/go || -L /usr/local/go ]]; then
    sudo mv -- /usr/local/go "$GO_BACKUP"
fi
touch "$STATE/go-installing"
sudo cp -a --no-preserve=ownership "$STATE/work/go" /usr/local/go

step 'Installing Go tools'
export PATH="/usr/local/go/bin:$HOME/.local/bin:$PATH"
export GOBIN="$HOME/.local/bin"
export GOPATH="$STATE/work/gopath"
export GOCACHE="$STATE/work/go-build"
export GOTOOLCHAIN=local
mkdir -p "$GOBIN"
GO_TOOLS=(
    golang.org/x/tools/gopls@latest
    mvdan.cc/gofumpt@latest
    github.com/go-delve/delve/cmd/dlv@latest
    github.com/air-verse/air@latest
    github.com/golangci/golangci-lint/cmd/golangci-lint@latest
)
for tool in "${GO_TOOLS[@]}"; do
    step "Installing Go tool: $tool"
    binary="${tool%@*}"
    binary="${binary##*/}"
    backup_path "$GOBIN/$binary"
    go install "$tool"
    [[ -x "$GOBIN/$binary" ]] || die "Go tool was not installed: $binary"
    go version -m "$GOBIN/$binary" >/dev/null
done

printf 'neovim\n' > "$STATE/checkpoint"
finish_installation
