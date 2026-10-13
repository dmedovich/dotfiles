#!/usr/bin/env bash
# A subshell gives staging files an EXIT cleanup without replacing the caller's trap.
install_git_defaults() (
    set -euo pipefail
    local source="$1" defaults="$2" target="$3" personal="$4" backup="$5"
    local staged='' footer=''
    [[ "$defaults" != "$target" && "$target" != "$personal" && "$defaults" != "$personal" ]] || die 'Git configuration paths must be distinct.'
    git config --no-includes --file "$source" --list >/dev/null
    if [[ -e "$target" || -L "$target" ]]; then
        git config --no-includes --file "$target" --list >/dev/null
    fi
    if [[ -e "$personal" || -L "$personal" ]]; then
        git config --no-includes --file "$personal" --list >/dev/null
    fi

    trap 'if [[ -n "$staged" ]]; then rm -f -- "$staged"; fi; if [[ -n "$footer" ]]; then rm -f -- "$footer"; fi' EXIT
    staged="$(mktemp)"
    footer="$(mktemp)"
    # Let Git quote paths. Keep the user's original content in the same location,
    # so its relative include/includeIf paths continue to resolve correctly.
    git config --file "$staged" include.path "$defaults"
    if [[ -e "$target" ]]; then
        printf '\n' >> "$staged"
        cat -- "$target" >> "$staged"
    fi
    git config --file "$footer" include.path "$personal"
    printf '\n' >> "$staged"
    cat -- "$footer" >> "$staged"
    git config --no-includes --file "$staged" --list >/dev/null

    "$backup" "$defaults" preserve
    "$backup" "$target" preserve
    mkdir -p "$(dirname -- "$defaults")" "$(dirname -- "$target")"
    install -m 0644 "$source" "$defaults"
    # The preserved personal config may contain private values.
    install -m 0600 "$staged" "$target"
    git config --includes --file "$target" --list >/dev/null
)
