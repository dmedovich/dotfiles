# dotfiles

Personal Linux dotfiles.

## Contents

- `git/.gitconfig` - shared Git defaults; existing preferences and identity are preserved.
- `git/.gitconfig.local.example` - optional template for machine-specific Git settings.
- `zsh/.zshrc` - zsh config for Oh My Zsh and powerlevel10k.
- `zsh/.p10k.zsh` - saved Powerlevel10k prompt configuration (lean, one line, Nerd Font v3 icons).
- `ghostty/.config/ghostty/config` - Ghostty config.
- `nvim/` - Neovim config.
- `vscodium/settings.json` - VSCodium user settings.
- `fonts/Mononoki.zip` - Mononoki Nerd Font archive.
- `scripts/install.sh` - full Fedora-oriented installer.
- `scripts/uninstall.sh` - restore previous settings and remove the recorded Fedora installation.
- `scripts/update-dev.sh` - update the developer workflow on an existing installation, with backups.
- `scripts/dotfiles-check` - per-repository checks for staged secrets, Go formatting and Go tests.

## Full install

Run from the repository root:

```sh
bash scripts/install.sh --check
bash scripts/install.sh
```

Run as your normal user, **not** `sudo bash scripts/install.sh`. Internet access and sudo privileges are required. Close Neovim before installing or uninstalling. Supported architectures are x86_64 and aarch64; the Go architecture is detected automatically.

The script installs Fedora packages, Ghostty, Oh My Zsh, zsh plugins, powerlevel10k, config files, Mononoki Nerd Font, Go, Go tools, Neovim plugins, Treesitter parsers, and Mason tools. It makes zsh your login shell automatically; log out and log in again afterwards. VSCodium itself and its extensions are **not installed**; see the VSCodium section below.

`--check` performs local checks without sudo or changes. Full installation also checks sudo, downloaded files, network access, shell/JSON/Lua syntax, available disk space (at least 2 GiB in HOME and 512 MiB at `/usr/local`, with additional room needed for builds), font detection, Ghostty configuration, and Neovim plugin/parser/language-server installation. Downloads and Neovim setup have timeouts; failures stop installation with a nonzero exit status.

If installation failed during Neovim setup, run `bash scripts/install.sh --resume` to finish the remaining steps, including selecting zsh. This preserves backups and reuses installed packages and language servers. Resume is refused if cleanup has already started or installation stopped before Neovim setup.

**Neovim 0.12+ with `vim.pack` is required.** After the package transaction, the script checks the actual `nvim` selected by PATH before replacing user configs. If Fedora provides an older version, install a compatible Neovim first. An older or broken `~/.local/bin/nvim` can shadow `/usr/bin/nvim`; the installer does not download nightly builds or replace that executable.

Before replacing these paths, the script moves existing files/directories (including symlinks) into a private backup journal:

```text
~/.gitconfig
~/.config/git/dotfiles.gitconfig
~/.zshrc
~/.p10k.zsh
~/.config/ghostty/config
~/.config/ghostty/config.ghostty
~/.config/VSCodium/User/settings.json
~/.config/nvim
```

Neovim's existing data, state and cache directories are backed up too, so existing plugins and Mason tools are preserved. Existing Go tools in `~/.local/bin` and the Mononoki font directory are backed up before replacement. Existing Oh My Zsh/plugins are kept. A previous `/usr/local/go` is moved to `/usr/local/.dotfiles-go-<uid>-<timestamp>-<pid>` before installing the new release.

The journal is stored in `~/.local/state/dotfiles-fedora/current` (or under `XDG_STATE_HOME`). Do not delete it until you no longer need cleanup/restoration. XDG roots and `ZSH_CUSTOM` must be normalized paths inside HOME; overlapping Neovim/state directories and a separate `ZDOTDIR` are rejected. Only one installation can be active at once. A repeat install stops without replacing backups; uninstall first. If installation fails, use the same uninstaller to undo recorded changes, then retry.

Each installation attempt saves its combined stdout/stderr to a separate private file:

```text
~/.local/state/dotfiles-fedora/logs/install-YYYYMMDD-HHMMSS-XXXXXX.log
```

With `XDG_STATE_HOME`, the log directory follows that setting. Output is still shown in the terminal. Step headers include timestamps; on failure the installer reports the last step, exit status and log path. Logging starts after the initial account/path checks and also captures subsequent prerequisite and sudo failures. `--check` and `--help` do not create logs. The active journal's `log-file` contains the path for that installation. Logs remain available after uninstalling and are not overwritten by the next attempt.

Go version can be pinned:

```sh
GO_VERSION=1.24.5 bash scripts/install.sh
```

Go defaults to the latest stable release. Go tools use `@latest`; an older pinned Go may be unable to build them, in which case installation stops. The Go target must match the laptop:

```sh
GO_OS=linux GO_ARCH=amd64 bash scripts/install.sh
```

## Cleanup / restore

Preview the recorded changes without sudo or modifications:

```sh
bash scripts/uninstall.sh --dry-run
```

Restore previous configs, Go and login shell and remove the introduced packages:

```sh
bash scripts/uninstall.sh
```

To restore user files and Go while keeping Fedora packages:

```sh
bash scripts/uninstall.sh --keep-packages
```

Cleanup restores the old shell before package removal. If you changed your shell again after installation, that choice is kept. It restores original files, removes newly created plugins/tools/fonts and Neovim runtime directories, and disables the Ghostty COPR only when the installer enabled it. Current managed config files (including edits made since installation) are retained under `~/.local/state/dotfiles-fedora/history/`; installed binaries and runtime caches are discarded. Go projects and pre-existing Go caches are not removed.

Only RPM packages newly introduced by the installer's DNF transactions are requested for removal, including their new dependencies. DNF shows the proposed transaction and asks for confirmation; review it if other programs were installed afterwards. Automatic dependency cleanup is disabled ([DNF documentation](https://dnf5.readthedocs.io/en/latest/commands/remove.8.html)). Package upgrades, shared system caches and previous/manual installations without a journal cannot be rolled back automatically. If cleanup fails or DNF removal is declined, the journal remains and cleanup can be retried. This lifecycle applies to the Fedora scripts; `install-void.sh` remains separate.

RPM signing-key records (`gpg-pubkey.*`, including `gpg-pubkey.(none)`) are excluded from installation snapshots and skipped in older journals. They are never requested for removal. `--keep-packages` skips the package journal entirely, so it can finish cleanup after an older version stopped on a signing-key record. Update the checkout and rerun cleanup; already restored files are kept in place.

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
  zoxide \
  python3 \
  ripgrep \
  tree-sitter-cli \
  make \
  gcc \
  gcc-c++ \
  util-linux-user
```

## Git

The full Fedora and Void installers copy `git/.gitconfig` to `$XDG_CONFIG_HOME/git/dotfiles.gitconfig` (default: `~/.config/git/dotfiles.gitconfig`). They prepend an include to `~/.gitconfig`, retain its existing contents, and append an optional include of `~/.gitconfig.local`. The old files are backed up; Fedora cleanup restores them. The personal override file is never replaced or removed.

Settings take precedence in this order: shared defaults, previous `~/.gitconfig` content, then `~/.gitconfig.local`. Relative includes in the previous config keep working because their content remains in `~/.gitconfig`. If `GIT_CONFIG_GLOBAL` points elsewhere, unset it before running the installer. No identity, credential helper or signing keys are bundled in the shared config.

Defaults include `main` for new repositories, Neovim as the editor, LF normalization on commit, pruning stale remote-tracking branches on fetch, and `pull.ff=only` (divergent branches require an explicit merge or rebase). Push uses `simple` with automatic upstream setup. Diffs use the histogram algorithm and moved-line highlighting; merge conflicts use `zdiff3`. See the [Git configuration documentation](https://git-scm.com/docs/git-config).

Aliases: `git st` (short status), `git sw` (switch), `git br` (branch), `git ci` (commit), `git lg` (graph of all branches).

Existing name/email settings keep working. For a new laptop, set your identity in the optional local file:

```sh
git config --file ~/.gitconfig.local user.name 'Your Name'
git config --file ~/.gitconfig.local user.email 'you@example.com'
```

Alternatively, copy `git/.gitconfig.local.example` to `~/.gitconfig.local` if that file does not exist yet, then edit it. The example is not installed automatically. `user.useConfigOnly=true` requires an explicitly configured identity for commits. To see where effective settings come from:

```sh
git config --show-origin --list
```

## zsh

The full installer also installs `zsh/.p10k.zsh` as `~/.p10k.zsh`, preserving the previous file for cleanup. `.zshrc` already loads this file. It controls prompt segments, colors and symbols; the theme itself is installed separately. After running `p10k configure`, copy the resulting `~/.p10k.zsh` back to `zsh/.p10k.zsh` to save the new appearance.

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
install -m 0644 zsh/.p10k.zsh ~/.p10k.zsh
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
  '+MasonInstall --quiet lua-language-server gopls zls' \
  +qa
```

`MasonInstall` waits for completion in headless mode ([Mason documentation](https://github.com/mason-org/mason.nvim/blob/main/doc/mason.txt)). `--quiet` prevents normal Go download messages on stderr from becoming Vim errors. The full installer additionally checks installation receipts and executable availability, and skips servers already installed successfully.

Mason uses the `mason.providers.client` provider to resolve metadata directly (GitHub API for GitHub releases), avoiding retries against `api.mason-registry.dev`. GitHub still needs to be reachable. Bootstrap output distinguishes plugin installation, Treesitter parsers and Mason language servers; Mason console logging is enabled and the Mason log path is printed before language-server installation.

For Go, `gopls` provides completion, diagnostics, code actions, import organization and gofumpt formatting. Saving a Go file adds missing imports, removes unused imports and formats the buffer. Servers installed through the system PATH are enabled too; `gopls` from PATH takes priority over Mason's copy. Standalone Go files are supported.

Completion opens while typing; use `Ctrl-Space` to open it manually, `Ctrl-N`/`Ctrl-P` to select and `Enter` to accept. Use `<Space>ca` for available fixes, `<Space>rn` to rename, `<Space>lf` to format and organize imports, and `<Space>ll` to run lint. Automatic golangci-lint checks run on opening and saving files, from the file's package directory. Unsaved edits use gopls diagnostics.

After upgrading Go, rebuild `gopls` and golangci-lint with the commands in the Go section. golangci-lint must be built with a Go version at least as new as the project's version; an older build can fail with exit code 3.

## Developer workflow

For an existing Fedora setup, close Neovim and run from this checkout:

```sh
sudo dnf install zoxide fzf fd-find python3
bash scripts/update-dev.sh
```

The updater requires an existing Go installation, Ghostty and Neovim 0.12+. It backs up the affected configs and binaries under `~/.local/state/dotfiles-dev-backups/` (or `XDG_STATE_HOME`), rebuilds Delve and Gitleaks with the current Go, copies the shell/Ghostty/Neovim configs and installs/verifies Neovim plugins. It preserves Neovim's existing plugin lockfile. It does not run the full Fedora installation again. An existing `~/.zshrc.local` is retained for personal overrides; changes made directly to `.zshrc` are kept in the backup. Restart the shell, Neovim and Ghostty afterwards.

In the shell:

| Command / key | Action |
| --- | --- |
| `p` / `p search` | Choose a Git repository with fzf and change to it |
| `croot` | Return to the current repository root |
| `z name` / `zi` | Jump to a visited directory / select one interactively |
| `Ctrl-R` | Search shared shell history without executing the selected command |
| `Ctrl-T` / `Alt-C` | Select a file / change directory with fzf |

`p` scans up to six levels under existing `~/Work`, `~/Projects`, `~/projects`, `~/src` and `~/dotfiles`, including Git worktrees. Customize the roots in `~/.zshrc.local`, for example `PROJECT_DIRS=("$HOME/code" "$HOME/Work")`. Commands beginning with a space are omitted from zsh history. [fzf shell integration](https://github.com/junegunn/fzf#setting-up-shell-integration), [zoxide](https://github.com/ajeetdsouza/zoxide).

Ghostty keeps ordinary tabs: `Ctrl-Shift-T` opens a tab in the current directory; `Ctrl-Shift-PageUp/PageDown` switches tabs. `Ctrl-Shift-E/O` splits right/down; `Ctrl-Shift-Enter` zooms a split. Closing a surface with a running foreground process asks for confirmation. Ghostty on Linux currently cannot restore tabs/splits after restart ([Ghostty documentation](https://ghostty.org/docs/config/reference#window-save-state)). Neovim saves project sessions with files, tabs and splits; run `p`, start `nvim` from the project root, then press `<Space>sr` to restore that project's layout. `<Space>sl` restores the last session, `<Space>ss` selects a session and `<Space>sd` stops saving it. Terminal processes are not restarted by session restoration.

Go debugging uses [nvim-dap-go](https://github.com/leoluz/nvim-dap-go), Delve and [nvim-dap-ui](https://github.com/rcarriga/nvim-dap-ui). Test execution uses [Neotest's Go adapter](https://github.com/nvim-neotest/neotest-go). Open a Go module before running tests/debugging; Delve's `dlv` executable must be on PATH.

| Neovim key | Action |
| --- | --- |
| `<Space>db` / `<Space>dB` | Toggle breakpoint / set conditional breakpoint |
| `<Space>dc` | Start or continue debugging; choose “Debug current package” for a main package |
| `<Space>dn` / `<Space>di` / `<Space>do` | Step over / into / out |
| `<Space>de` / `<Space>du` / `<Space>dq` | Evaluate expression / toggle panels / stop debugger |
| `<Space>dt` | Debug the Go test under the cursor |
| `<Space>Tn` / `<Space>Tf` | Run nearest test / current test file |
| `<Space>Tp` / `<Space>Ta` | Run package (including subpackages) / module tests |
| `<Space>Tl` / `<Space>Tx` | Repeat last run / stop tests |
| `<Space>Ts` / `<Space>To` | Test summary / test output |
| `<Space>Tj` / `<Space>Tk` | Jump to next / previous failed test |

Test runs use `-count=1 -timeout=60s`. Commands starting a new run save the current buffer first. The test summary and diagnostics show failures; the output panel contains detailed compiler/test output. Session/debug/test commands are also listed by which-key after pressing the corresponding prefix.

Enable commit checks once **inside each repository**:

```sh
cd /path/to/project
dotfiles-check install
```

This installs a self-contained `.git/hooks/pre-commit`. Existing hooks and `core.hooksPath` are respected; with another hook manager, call `dotfiles-check` from that manager instead. Run `dotfiles-check` manually to check the current index. Remove the installed hook to disable it; rerun `dotfiles-check install` after updating the checker to refresh its installed copy.

Checks reject staged whitespace errors, scan staged additions using [Gitleaks](https://github.com/gitleaks/gitleaks) with secrets redacted, verify Go files with `gofmt` and run affected package tests with `-count=1 -timeout=30s` (120 seconds per invocation including builds). Format and stage files again when formatting fails; the hook never rewrites files or stages changes. Go module changes test the whole changed module; workspace changes test every checked-in module. Tests run from a temporary export of the **index**, so unstaged edits and untracked files cannot hide a failure. Deleted files and nested modules are handled. Standalone Go files receive formatting checks only. Dependencies must be available; local `replace` targets outside the repository and uncommitted sibling modules are not included. Go checks discover the staged workspace using `GOWORK=auto`, independently of any absolute workspace override in the current shell. These are quick checks of touched packages; run your full suite/CI separately for changes affecting their dependents.

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
go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@latest
go install github.com/zricethezav/gitleaks/v8@latest
```

## Sync checks

Run the Fedora lifecycle tests (from a checkout inside HOME):

```sh
python3 -B -m unittest discover -s tests -v
```

Tests use temporary files inside the checkout and mock sudo, RPM and DNF. They do not install packages or change your actual configs or login shell.

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
diff -u zsh/.p10k.zsh ~/.p10k.zsh
```
