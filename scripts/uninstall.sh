#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/fedora.sh
source "$SCRIPT_DIR/lib/fedora.sh"

DRY_RUN=false
KEEP_PACKAGES=false
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --keep-packages) KEEP_PACKAGES=true ;;
        --help)
            echo 'Usage: bash scripts/uninstall.sh [--dry-run] [--keep-packages]'
            echo 'Restore previous configs, Go and login shell; remove packages introduced by install.sh.'
            echo 'DNF shows its transaction and asks for confirmation. Backups and removed configs are archived.'
            exit 0 ;;
        *) die "Unknown argument: $arg" ;;
    esac
done
check_host
check_layout
[[ -d "$STATE" && ! -L "$STATE" ]] || die "No recorded Fedora installation at $STATE. Older/manual installations cannot be safely removed automatically."
[[ "$(cat "$STATE/format")" == 1 && "$(cat "$STATE/user")" == "$USER_NAME" && "$(cat "$STATE/home")" == "$HOME" ]] || die 'Installation state belongs to another user or format.'

if ! $DRY_RUN; then
    sudo -v
    lock_state
fi
shopt -s nullglob
entries=("$STATE"/paths/*)
for entry in "${entries[@]}"; do
    [[ -d "$entry" && ! -L "$entry" ]] || die "Invalid journal entry: $entry"
    target="$(cat "$entry/target")"
    validate_path "$target"
    [[ "$(cat "$entry/kind")" == existing || "$(cat "$entry/kind")" == absent ]] || die "Invalid path record: $entry"
done

# Validate package records before restoring anything. --keep-packages does not
# need the RPM journal; older journals may contain imported signing keys.
packages=()
if ! $KEEP_PACKAGES && [[ -f "$STATE/packages.new" ]]; then
    while IFS= read -r package; do
        [[ "$package" != gpg-pubkey.* ]] || continue
        [[ "$package" =~ ^[a-zA-Z0-9][a-zA-Z0-9_+.-]*$ ]] || die "Invalid package name: $package"
        if rpm -q "$package" >/dev/null 2>&1; then packages+=("$package"); fi
    done < "$STATE/packages.new"
fi

if [[ -f "$STATE/shell.before" && ! -f "$STATE/shell-restored" ]]; then
    previous="$(cat "$STATE/shell.before")"
    installed="$(cat "$STATE/shell.after")"
    current="$(login_shell)"
    if [[ "$current" == "$installed" ]]; then
        [[ -x "$previous" ]] && grep -Fxq "$previous" /etc/shells || die 'Previous login shell is unavailable; restore it before cleanup.'
        log "Restore login shell: $previous"
        if ! $DRY_RUN; then
            sudo chsh -s "$previous" "$USER_NAME"
            [[ "$(login_shell)" == "$previous" ]] || die 'Login shell was not restored.'
        fi
    elif [[ "$current" != "$previous" ]]; then
        warn "Login shell was changed after installation; keeping $current."
    fi
    if ! $DRY_RUN; then touch "$STATE/shell-restored"; fi
fi

if [[ -f "$STATE/go-backup" && ! -f "$STATE/go-restored" ]]; then
    go_backup="$(cat "$STATE/go-backup")"
    [[ "$go_backup" =~ ^/usr/local/\.dotfiles-go-$UID-[0-9]{14}-[0-9]+$ ]] || die 'Invalid Go backup path.'
    log "Restore previous /usr/local/go (backup: $go_backup)"
    if ! $DRY_RUN; then
        if [[ -f "$STATE/go-installing" ]] && exists /usr/local/go && ! exists "$go_backup.removed"; then
            sudo mv -- /usr/local/go "$go_backup.removed"
        fi
        if exists "$go_backup"; then sudo mv -- "$go_backup" /usr/local/go; fi
        touch "$STATE/go-restored"
    fi
fi

# Keep the detached Go until restoration is recorded, making interrupted cleanup retryable.
if [[ -f "$STATE/go-restored" ]]; then
    go_backup="$(cat "$STATE/go-backup")"
    [[ "$go_backup" =~ ^/usr/local/\.dotfiles-go-$UID-[0-9]{14}-[0-9]+$ ]] || die 'Invalid Go backup path.'
    if ! $DRY_RUN && exists "$go_backup.removed"; then sudo rm -rf -- "$go_backup.removed"; fi
fi

for entry in "${entries[@]}"; do
    [[ ! -f "$entry/restored" ]] || continue
    target="$(cat "$entry/target")"
    log "Restore/remove managed path: $target"
    $DRY_RUN && continue
    if [[ ! -f "$entry/ready" ]] && ! exists "$entry/backup"; then
        touch "$entry/restored"
        continue
    fi
    if exists "$target" && ! exists "$entry/removed"; then
        mv -- "$target" "$entry/removed"
    fi
    if exists "$entry/backup"; then
        mkdir -p "$(dirname -- "$target")"
        mv -- "$entry/backup" "$target"
    fi
    touch "$entry/restored"
done

if ! $DRY_RUN; then
    for entry in "${entries[@]}"; do
        if [[ -f "$entry/restored" && ! -f "$entry/keep-removed" ]] && exists "$entry/removed"; then
            rm -rf -- "$entry/removed"
        fi
    done
fi

if [[ -f "$STATE/ghostty-copr" && ! -f "$STATE/copr-restored" ]]; then
    log 'Disable the Ghostty COPR enabled by the installer'
    if ! $DRY_RUN; then
        sudo dnf copr disable -y scottames/ghostty
        touch "$STATE/copr-restored"
    fi
fi

if ! $KEEP_PACKAGES && (( ${#packages[@]} )); then
    log "Remove packages introduced by the installer: ${packages[*]}"
    if ! $DRY_RUN; then
        sudo dnf remove --no-autoremove "${packages[@]}"
    fi
fi

if $DRY_RUN; then
    log 'Dry run complete; nothing was changed.'
else
    if command -v fc-cache >/dev/null; then fc-cache -f; fi
    if [[ -d "$STATE/work" ]]; then
        chmod -R u+w "$STATE/work"
        rm -rf -- "$STATE/work"
    fi
    printf 'removed\n' > "$STATE/status"
    archive="$STATE_ROOT/history/$(date +%Y%m%d-%H%M%S)-$$"
    mkdir -p "$(dirname -- "$archive")"
    mv -- "$STATE" "$archive"
    log "Cleanup complete. Original backups and removed configs are retained in $archive."
    log 'Log out and log in again. Package upgrades and shared system caches are not rolled back.'
fi
