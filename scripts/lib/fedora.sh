#!/usr/bin/env bash
# Shared helpers. Installation state is data and must never be sourced.

log() { printf '==> %s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
exists() { [[ -e "$1" || -L "$1" ]]; }

step() {
    INSTALL_STEP="$*"
    printf '[%s] ==> %s\n' "$(date --iso-8601=seconds)" "$INSTALL_STEP"
}

start_install_logging() {
    local directory="$STATE_ROOT/logs" cmd
    for cmd in tee mktemp date; do
        command -v "$cmd" >/dev/null || die "Required logging command is missing: $cmd"
    done
    validate_path "$directory"
    [[ ! -L "$STATE_ROOT" && ! -L "$directory" ]] || die 'Log directories must not be symlinks.'
    mkdir -p "$directory"
    chmod 700 "$STATE_ROOT" "$directory"
    INSTALL_LOG_FILE="$(mktemp "$directory/install-$(date +%Y%m%d-%H%M%S)-XXXXXX.log")"
    INSTALL_STATE_CREATED=false
    # Retain the terminal descriptors so EXIT can close the pipe and wait for tee.
    # Start tee before taking the installation lock, so it never inherits that lock.
    exec {INSTALL_STDOUT_FD}>&1 {INSTALL_STDERR_FD}>&2
    exec > >(tee --ignore-interrupts --output-error=warn-nopipe -- "$INSTALL_LOG_FILE") 2>&1
    INSTALL_LOG_PID=$!
    trap 'install_exit $?' EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    log "Installation log: $INSTALL_LOG_FILE"
}

check_host() {
    [[ $EUID != 0 ]] || die 'Run as your normal user, without sudo. The script requests sudo when needed.'
    [[ -r /etc/os-release ]] || die 'Cannot detect the operating system.'
    # shellcheck disable=SC1091
    source /etc/os-release
    [[ "${ID:-}" == fedora ]] || die "This script supports Fedora, detected: ${ID:-unknown}."
    for cmd in sudo dnf rpm getent flock realpath sort comm awk df; do
        command -v "$cmd" >/dev/null || die "Required system command is missing: $cmd"
    done
    USER_NAME="$(id -un)"
    ACCOUNT="$(getent passwd "$USER_NAME")"
    [[ -n "$ACCOUNT" ]] || die 'Cannot read the current user account.'
    [[ "$HOME" == "$(cut -d: -f6 <<< "$ACCOUNT")" && "$HOME" == /* && "$HOME" != / ]] || die 'HOME must match the current user account.'
    [[ -d "$HOME" && -w "$HOME" ]] || die 'Home directory is not writable.'
}

check_layout() {
    [[ -z "${ZDOTDIR:-}" || "$ZDOTDIR" == "$HOME" ]] || die 'ZDOTDIR outside HOME is unsupported; zsh config is installed to ~/.zshrc.'
    CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
    DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
    CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
    STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
    STATE_ROOT="$STATE_HOME/dotfiles-fedora"
    STATE="$STATE_ROOT/current"
    for path in "$CONFIG_HOME" "$DATA_HOME" "$CACHE_HOME" "$STATE_HOME" "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"; do
        validate_path "$path"
    done
    local roots=("$CONFIG_HOME/nvim" "$DATA_HOME/nvim" "$CACHE_HOME/nvim" "$STATE_HOME/nvim" "$STATE_ROOT" "$DATA_HOME/fonts/mononoki" "$HOME/.local/bin" "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}") i j
    for ((i = 0; i < ${#roots[@]}; i++)); do
        roots[i]="$(realpath -m -- "$(dirname -- "${roots[i]}")")/$(basename -- "${roots[i]}")"
    done
    for ((i = 0; i < ${#roots[@]}; i++)); do
        for ((j = 0; j < ${#roots[@]}; j++)); do
            [[ "$i" == "$j" ]] && continue
            [[ "${roots[i]}/" != "${roots[j]}/"* ]] || die 'Overlapping XDG paths are unsupported.'
        done
    done
}

validate_path() {
    local path="$1" parent
    [[ "$path" == "$HOME/"* && "$path" != *$'\n'* && "$path" != *$'\t'* ]] || die "Expected a path inside HOME: $path"
    [[ "$(realpath -ms -- "$path")" == "$path" ]] || die "Path must be normalized: $path"
    parent="$(realpath -m -- "$(dirname -- "$path")")"
    [[ "$parent" == "$(realpath -m -- "$HOME")" || "$parent" == "$(realpath -m -- "$HOME")/"* ]] || die "Parent resolves outside HOME: $path"
    [[ "$path" != "$HOME/.ssh"* && "$path" != "$HOME/.gnupg"* ]] || die "Unsupported managed path: $path"
}

lock_state() {
    validate_path "$STATE_ROOT"
    [[ ! -L "$STATE_ROOT" && ! -L "$STATE" ]] || die 'Installation state must not be a symlink.'
    mkdir -p "$STATE_ROOT"
    chmod 700 "$STATE_ROOT"
    exec 9> "$STATE_ROOT/lock"
    flock -n 9 || die 'Another installer/uninstaller is running.'
}

check_space() {
    local available
    available="$(df -Pk "$1" | awk 'END {print $4}')"
    [[ "$available" =~ ^[0-9]+$ && "$available" -ge "$2" ]] || die "Insufficient free space at $1 (need at least $(( $2 / 1024 )) MiB, plus room for backups)."
}

check_neovim() {
    NVIM_LOG_FILE=/dev/null nvim --clean --headless -l "$SCRIPT_DIR/check-neovim.lua" "$REPO_ROOT" || die 'Neovim 0.12+ with vim.pack and valid Lua configs are required. Install a compatible version before continuing; no user configs have been replaced.'
}

login_shell() { getent passwd "$USER_NAME" | cut -d: -f7; }

make_zsh_default() {
    local target current
    target="$(command -v zsh)"
    [[ -x "$target" ]] && grep -Fxq "$target" /etc/shells || die "$target is not an available login shell in /etc/shells."
    current="$(login_shell)"
    [[ -n "$current" ]] || die 'Cannot read the current login shell.'
    if [[ "$current" != "$target" ]]; then
        printf '%s\n' "$current" > "$STATE/shell.before"
        printf '%s\n' "$target" > "$STATE/shell.after"
        sudo chsh -s "$target" "$USER_NAME"
        [[ "$(login_shell)" == "$target" ]] || die 'Login shell change was not applied.'
    fi
}

snapshot_packages() {
    # RPM signing keys can have architecture "(none)"; they are not managed packages.
    rpm -qa --qf '%{NAME}.%{ARCH}\n' | awk '!/^gpg-pubkey\./' | LC_ALL=C sort -u
}

install_packages() {
    local result=0
    snapshot_packages > "$STATE/transaction.before" || die 'Cannot snapshot installed packages.'
    sudo dnf install -y "$@" || result=$?
    snapshot_packages > "$STATE/packages.now" || die 'Cannot record installed packages.'
    LC_ALL=C comm -13 "$STATE/transaction.before" "$STATE/packages.now" >> "$STATE/packages.transactions" || die 'Cannot record the package transaction.'
    # Keep the union of our own transactions, not packages installed later by other tools.
    LC_ALL=C sort -u "$STATE/packages.transactions" > "$STATE/packages.new.tmp" || die 'Cannot record new packages.'
    mv "$STATE/packages.new.tmp" "$STATE/packages.new" || die 'Cannot save the package journal.'
    return "$result"
}

install_exit() {
    local code="$1" logging_code=0
    trap - EXIT INT TERM
    set +e
    if [[ "$code" != 0 ]]; then
        warn "Installation failed during: ${INSTALL_STEP:-initialization} (exit $code)."
        if [[ "${INSTALL_STATE_CREATED:-false}" == true ]]; then
            printf 'failed\n' > "$STATE/status"
            warn "Backups are retained in $STATE. Run bash scripts/uninstall.sh to undo recorded changes."
        fi
    fi
    if [[ -n "${INSTALL_LOG_PID:-}" ]]; then
        printf '[%s] Installation ended with exit status %s.\n' "$(date --iso-8601=seconds)" "$code"
        log "Installation log: $INSTALL_LOG_FILE"
        # Preserve the installer's exit code; tee must finish before callers read the log.
        exec 1>&"$INSTALL_STDOUT_FD" 2>&"$INSTALL_STDERR_FD"
        exec {INSTALL_STDOUT_FD}>&- {INSTALL_STDERR_FD}>&-
        wait "$INSTALL_LOG_PID" || logging_code=$?
        if [[ "$logging_code" != 0 ]]; then
            warn "Could not finish writing installation log: $INSTALL_LOG_FILE (exit $logging_code)."
            if [[ "$code" == 0 ]]; then code="$logging_code"; fi
        fi
    fi
    exit "$code"
}

# Write intent before moving an original; cleanup also handles incomplete moves.
backup_path() {
    local target="$1" entry
    validate_path "$target"
    entry="$STATE/paths/$(printf '%s' "$target" | sha256sum | cut -d' ' -f1)"
    [[ ! -e "$entry" ]] || die "Path was already recorded: $target"
    mkdir "$entry"
    printf '%s\n' "$target" > "$entry/target"
    if [[ "${2:-}" == preserve ]]; then touch "$entry/keep-removed"; fi
    if exists "$target"; then
        printf 'existing\n' > "$entry/kind"
        mv -- "$target" "$entry/backup"
    else
        printf 'absent\n' > "$entry/kind"
    fi
    touch "$entry/ready"
}

record_if_absent() { if ! exists "$1"; then backup_path "$1" preserve; fi; }

replace_file() {
    backup_path "$2" preserve
    mkdir -p "$(dirname -- "$2")"
    install -m 0644 "$1" "$2"
}

clone_missing() {
    local url="$1" destination="$2"
    validate_path "$destination"
    if exists "$destination"; then
        [[ -d "$destination" ]] || die "Expected a directory: $destination"
        log "Keeping existing $destination"
        return
    fi
    if [[ "$destination" != "$HOME/.oh-my-zsh/"* || ! -e "$STATE/oh-my-zsh-created" ]]; then
        backup_path "$destination"
    fi
    if [[ "$destination" == "$HOME/.oh-my-zsh" ]]; then touch "$STATE/oh-my-zsh-created"; fi
    mkdir -p "$(dirname -- "$destination")"
    git clone --depth=1 "$url" "$destination"
}
