"""Exercise rollback with real files and mocked RPM/DNF/sudo, without host changes.

Run from a checkout inside HOME: python3 -B -m unittest discover -s tests -v
"""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]
MOCK = r'''#!/usr/bin/env python3
import json, os, pathlib, shutil, subprocess, sys
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
root = pathlib.Path(os.environ["TEST_ROOT"])
with (root / "calls").open("a") as log:
    log.write(json.dumps([name, *args]) + "\n")
def mapped(path):
    if path.startswith("/usr/local/"):
        return str(root / "system" / path.lstrip("/"))
    return path
if name == "sudo":
    if args == ["-v"]:
        sys.exit(0)
    if args[0] == "chsh":
        (root / "shell").write_text(args[args.index("-s") + 1] + "\n")
        sys.exit(0)
    if args[0] in ("mv", "rm"):
        sys.exit(subprocess.call(["/usr/bin/" + args[0], *[mapped(a) for a in args[1:]]]))
    if args[0] == "dnf":
        sys.exit(subprocess.call(args))
    sys.exit("Unexpected sudo call: " + repr(args))
elif name == "rpm":
    packages = (root / "rpm").read_text().splitlines()
    if args[0] == "-qa":
        print("\n".join(packages))
    else:
        sys.exit(0 if args[-1] in packages else 1)
elif name == "dnf":
    if args[0] == "remove":
        if os.environ.get("TEST_DECLINE"):
            sys.exit(1)
        packages = (root / "rpm").read_text().splitlines()
        (root / "rpm").write_text("\n".join(p for p in packages if p not in args[2:]) + "\n")
    elif args[0] == "install":
        packages = (root / "rpm").read_text().splitlines()
        (root / "rpm").write_text("\n".join(sorted(set(packages + [p + ".x86_64" for p in args[2:]]))) + "\n")
        if os.environ.get("TEST_INSTALL_FAILURE"):
            sys.exit(1)
elif name == "nvim":
    sys.exit(1 if os.environ.get("TEST_OLD_NVIM") else 0)
elif name == "df":
    print("Filesystem 1024-blocks Used Available Capacity Mounted on\ntest 90000000 100 89999900 1% /")
elif name == "fc-cache":
    pass
else:
    sys.exit("Unexpected mock: " + name)
'''


class FedoraLifecycle(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix=".fedora-test-", dir=REPO)
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.scripts = self.root / "scripts"
        shutil.copytree(REPO / "scripts", self.scripts)
        # Only account/writability checks and /usr/local existence are substituted.
        # All journal parsing, backup moves, restoration and path validation are real.
        with (self.scripts / "lib/fedora.sh").open("a") as helper:
            helper.write('''
check_host() { USER_NAME="$(id -un)"; }
login_shell() { cat "$TEST_ROOT/shell"; }
exists() {
    local target="$1"
    if [[ "$target" == /usr/local/* ]]; then target="$TEST_ROOT/system$target"; fi
    [[ -e "$target" || -L "$target" ]]
}
''')
        self.bin = self.root / "bin"
        self.bin.mkdir()
        for name in ("sudo", "rpm", "dnf", "fc-cache", "df", "nvim"):
            path = self.bin / name
            path.write_text(MOCK)
            path.chmod(0o755)
        self.env = dict(os.environ, TEST_ROOT=str(self.root))
        self.env.pop("ZDOTDIR", None)
        self.env.pop("ZSH_CUSTOM", None)
        self.env["PATH"] = str(self.bin) + ":/usr/bin:/bin"
        for name in ("zsh", "git", "curl", "jq", "fc-match", "tar", "unzip", "fzf", "fd", "rg", "tree-sitter", "make", "gcc", "g++", "chsh", "sha256sum", "timeout"):
            if shutil.which(name, path=self.env["PATH"]) is None:
                path = self.bin / name
                path.write_text("#!/bin/sh\nexit 99\n")
                path.chmod(0o755)
        for kind, suffix in (("CONFIG", "config"), ("DATA", "data"), ("CACHE", "cache"), ("STATE", "state")):
            self.env[f"XDG_{kind}_HOME"] = str(self.root / suffix)
        self.state = self.root / "state/dotfiles-fedora/current"
        (self.state / "paths").mkdir(parents=True)
        for name, value in (("format", "1"), ("user", os.environ.get("USER") or subprocess.check_output(["id", "-un"], text=True).strip()), ("home", str(Path.home())), ("status", "complete")):
            (self.state / name).write_text(value + "\n")
        (self.root / "rpm").write_text("existing.x86_64\nnew-tool.x86_64\nnew-dep.x86_64\n")
        (self.root / "shell").write_text("/bin/bash\n")

    def run_script(self, script="uninstall.sh", *args, success=True, **env):
        result = subprocess.run(["bash", str(self.scripts / script), *args], env=self.env | env, text=True, capture_output=True)
        if success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def shell(self, code, success=True, **env):
        prefix = 'set -Eeuo pipefail; source "$TEST_ROOT/scripts/lib/fedora.sh"; check_layout; '
        result = subprocess.run(["bash", "-c", prefix + code], env=self.env | env, text=True, capture_output=True)
        self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
        return result

    def target(self, name, content=None):
        path = self.root / "managed" / name
        path.parent.mkdir(parents=True, exist_ok=True)
        if content is not None:
            path.write_text(content)
        return path

    def record(self, path, preserve=False):
        self.shell('backup_path "$TEST_TARGET" ' + ("preserve" if preserve else ""), TEST_TARGET=str(path))
        return self.state / "paths" / hashlib.sha256(str(path).encode()).hexdigest()

    def calls(self):
        path = self.root / "calls"
        return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []

    def install_git(self, target, defaults, personal, success=True):
        return self.shell(
            'source "$TEST_ROOT/scripts/lib/git.sh"; install_git_defaults "$TEST_SOURCE" "$TEST_DEFAULTS" "$TEST_TARGET" "$TEST_PERSONAL" backup_path',
            success=success,
            TEST_SOURCE=str(REPO / "git/.gitconfig"), TEST_DEFAULTS=str(defaults),
            TEST_TARGET=str(target), TEST_PERSONAL=str(personal),
        )

    def git_value(self, target, key):
        return subprocess.check_output(
            ["git", "config", "--includes", "--file", str(target), "--get", key],
            cwd=self.root, env=self.env, text=True,
        ).strip()

    def test_git_defaults_apply_to_new_repositories_and_are_removed_on_cleanup(self):
        target = self.target("git-main")
        defaults = self.target("git defaults.conf")
        personal = self.target("git-personal")
        self.install_git(target, defaults, personal)
        self.assertEqual(self.git_value(target, "core.editor"), "nvim")
        self.assertEqual(self.git_value(target, "pull.ff"), "only")
        self.assertEqual(self.git_value(target, "user.useConfigOnly"), "true")
        self.assertFalse(personal.exists())
        git_env = self.env | {"GIT_CONFIG_GLOBAL": str(target), "GIT_CONFIG_NOSYSTEM": "1"}
        repository = self.root / "new-repo"
        subprocess.run(["git", "init", "--quiet", str(repository)], env=git_env, check=True)
        branch = subprocess.check_output(["git", "-C", str(repository), "symbolic-ref", "--short", "HEAD"], env=git_env, text=True)
        self.assertEqual(branch.strip(), "main")
        self.run_script("uninstall.sh", "--keep-packages")
        self.assertFalse(target.exists())
        self.assertFalse(defaults.exists())

    def test_git_identity_preferences_and_relative_includes_survive_install_and_restore(self):
        original = '[user]\n name = Existing User\n[include]\n path = identity.inc\n[core]\n editor = vim'
        target = self.target("git-main", original)
        identity = self.target("identity.inc", '[user]\n email = existing@example.test\n')
        defaults = self.target("git defaults.conf", '[init]\n defaultBranch = old-default\n')
        personal = self.target("git-personal", '[user]\n name = Laptop User\n[fetch]\n prune = false\n')
        personal_content = personal.read_bytes()
        self.install_git(target, defaults, personal)
        self.assertEqual(self.git_value(target, "user.name"), "Laptop User")
        self.assertEqual(self.git_value(target, "user.email"), "existing@example.test")
        self.assertEqual(self.git_value(target, "core.editor"), "vim")
        self.assertEqual(self.git_value(target, "fetch.prune"), "false")
        self.assertEqual(self.git_value(target, "init.defaultBranch"), "main")
        self.assertEqual(target.stat().st_mode & 0o777, 0o600)
        self.run_script("uninstall.sh", "--keep-packages")
        self.assertEqual(target.read_text(), original)
        self.assertEqual(defaults.read_text(), '[init]\n defaultBranch = old-default\n')
        self.assertEqual(personal.read_bytes(), personal_content)
        self.assertEqual(identity.read_text(), '[user]\n email = existing@example.test\n')

    def test_invalid_existing_git_config_is_rejected_before_backups_or_changes(self):
        target = self.target("git-main", '[broken config\n')
        defaults = self.target("git-defaults")
        personal = self.target("git-personal")
        self.install_git(target, defaults, personal, success=False)
        self.assertEqual(target.read_text(), '[broken config\n')
        self.assertFalse(defaults.exists())
        self.assertEqual(list((self.state / "paths").iterdir()), [])

    def test_invalid_personal_git_override_is_rejected_before_changes(self):
        target = self.target("git-main", '[user]\n name = Existing User\n')
        defaults = self.target("git-defaults")
        personal = self.target("git-personal", '[broken override\n')
        self.install_git(target, defaults, personal, success=False)
        self.assertEqual(target.read_text(), '[user]\n name = Existing User\n')
        self.assertFalse(defaults.exists())
        self.assertEqual(list((self.state / "paths").iterdir()), [])

    def test_restore_existing_and_remove_new_files_and_runtime(self):
        old = self.target("config", "original")
        old_entry = self.record(old, preserve=True)
        old.write_text("edited after installation")
        new = self.target("new-tool")
        self.record(new)
        new.write_text("installed tool")
        runtime = self.target("runtime")
        self.record(runtime)
        runtime.mkdir()
        (runtime / "plugin").write_text("downloaded plugin")
        self.run_script("uninstall.sh", "--keep-packages")
        self.assertEqual(old.read_text(), "original")
        self.assertFalse(new.exists())
        self.assertFalse(runtime.exists())
        archive = next((self.state.parent / "history").iterdir())
        self.assertEqual((archive / "paths" / old_entry.name / "removed").read_text(), "edited after installation")
        self.assertEqual(len(list(archive.glob("paths/*/removed"))), 1)

    def test_symlink_is_restored_without_touching_its_destination(self):
        destination = self.target("source", "original source")
        link = self.target("config-link")
        link.symlink_to(destination)
        self.record(link, preserve=True)
        link.write_text("installed config")
        self.run_script("uninstall.sh", "--keep-packages")
        self.assertTrue(link.is_symlink())
        self.assertEqual(destination.read_text(), "original source")

    def test_dry_run_does_not_modify_files_or_call_sudo(self):
        path = self.target("config", "before")
        self.record(path)
        path.write_text("installed")
        self.run_script("uninstall.sh", "--dry-run")
        self.assertEqual(path.read_text(), "installed")
        self.assertTrue(self.state.is_dir())
        self.assertFalse(any(call[0] == "sudo" for call in self.calls()))

    def test_only_recorded_new_packages_are_requested_for_removal(self):
        (self.state / "packages.new").write_text("new-tool.x86_64\nnew-dep.x86_64\nalready-gone.x86_64\n")
        self.run_script()
        removals = [call for call in self.calls() if call[:2] == ["dnf", "remove"]]
        self.assertEqual(removals, [["dnf", "remove", "--no-autoremove", "new-tool.x86_64", "new-dep.x86_64"]])
        self.assertIn("existing.x86_64", (self.root / "rpm").read_text())

    def test_declined_package_removal_is_retryable(self):
        path = self.target("config", "before")
        self.record(path, preserve=True)
        path.write_text("installed")
        (self.state / "packages.new").write_text("new-tool.x86_64\n")
        self.run_script(success=False, TEST_DECLINE="1")
        self.assertEqual(path.read_text(), "before")
        self.assertTrue(self.state.exists())
        self.run_script()
        self.assertEqual(path.read_text(), "before")

    def test_shell_is_restored_before_package_removal(self):
        (self.state / "shell.before").write_text("/bin/sh\n")
        (self.state / "shell.after").write_text("/bin/bash\n")
        (self.state / "packages.new").write_text("new-tool.x86_64\n")
        self.run_script()
        self.assertEqual((self.root / "shell").read_text(), "/bin/sh\n")
        calls = self.calls()
        change = next(i for i, call in enumerate(calls) if call[:2] == ["sudo", "chsh"])
        remove = next(i for i, call in enumerate(calls) if call[:2] == ["dnf", "remove"])
        self.assertLess(change, remove)

    def test_zsh_is_selected_automatically_and_original_shell_recorded_once(self):
        zsh = shutil.which("zsh", path="/usr/bin:/bin")
        if not zsh:
            self.skipTest("zsh is not available for shell validation")
        self.shell('USER_NAME="$(id -un)"; make_zsh_default; make_zsh_default')
        self.assertEqual((self.root / "shell").read_text(), zsh + "\n")
        self.assertEqual((self.state / "shell.before").read_text(), "/bin/bash\n")
        self.assertEqual(len([c for c in self.calls() if c[:2] == ["sudo", "chsh"]]), 1)

    def test_manual_shell_change_is_preserved(self):
        (self.state / "shell.before").write_text("/bin/sh\n")
        (self.state / "shell.after").write_text("/usr/bin/zsh\n")
        self.run_script("uninstall.sh", "--keep-packages")
        self.assertEqual((self.root / "shell").read_text(), "/bin/bash\n")
        self.assertFalse(any(call[:2] == ["sudo", "chsh"] for call in self.calls()))

    def test_previous_go_is_restored_and_new_go_discarded(self):
        backup = f"/usr/local/.dotfiles-go-{os.getuid()}-20261013123456-123"
        previous = self.root / "system" / backup.lstrip("/")
        previous.mkdir(parents=True)
        (previous / "old").touch()
        current = previous.parent / "go"
        current.mkdir()
        (current / "new").touch()
        (self.state / "go-backup").write_text(backup + "\n")
        (self.state / "go-installing").touch()
        self.run_script("uninstall.sh", "--keep-packages")
        self.assertTrue((current / "old").exists())
        self.assertFalse((current / "new").exists())
        self.assertFalse(Path(str(previous) + ".removed").exists())

    def test_interrupted_go_restore_keeps_restored_go_on_retry(self):
        backup = f"/usr/local/.dotfiles-go-{os.getuid()}-20261013123456-123"
        system = self.root / "system/usr/local"
        (system / "go").mkdir(parents=True)
        (system / "go/old").touch()
        detached = system / (Path(backup).name + ".removed")
        detached.mkdir()
        (detached / "new").touch()
        (self.state / "go-backup").write_text(backup + "\n")
        (self.state / "go-installing").touch()
        self.run_script("uninstall.sh", "--keep-packages")
        self.assertTrue((system / "go/old").exists())
        self.assertFalse(detached.exists())

    def test_new_go_is_removed_when_no_previous_installation_existed(self):
        backup = f"/usr/local/.dotfiles-go-{os.getuid()}-20261013123456-123"
        current = self.root / "system/usr/local/go"
        current.mkdir(parents=True)
        (current / "installed").touch()
        (self.state / "go-backup").write_text(backup + "\n")
        (self.state / "go-installing").touch()
        self.run_script("uninstall.sh", "--keep-packages")
        self.assertFalse(current.exists())
        self.assertEqual(list(current.parent.iterdir()), [])

    def test_failed_backup_move_keeps_original(self):
        path = self.target("untouched", "original")
        entry = self.record(path)
        shutil.move(entry / "backup", path)
        (entry / "ready").unlink()
        self.run_script("uninstall.sh", "--keep-packages")
        self.assertEqual(path.read_text(), "original")

    def test_overlap_and_unsafe_paths_are_rejected(self):
        self.shell('validate_path /tmp/outside-home', success=False)
        self.shell('validate_path "$TEST_ROOT/../escape"', success=False)
        self.shell(":", success=False, XDG_DATA_HOME=self.env["XDG_CONFIG_HOME"])
        link = self.target("outside")
        link.symlink_to("/tmp", target_is_directory=True)
        self.shell('validate_path "$TEST_TARGET/file"', success=False, TEST_TARGET=str(link))

    def test_transaction_failure_still_records_new_packages(self):
        self.shell('snapshot_packages > "$STATE/packages.before"; if install_packages extra; then exit 99; fi', TEST_INSTALL_FAILURE="1")
        self.assertEqual((self.state / "packages.new").read_text(), "extra.x86_64\n")

    def test_preflight_rejects_old_neovim_without_changes(self):
        shutil.rmtree(self.state)
        for directory in ("git", "zsh", "ghostty", "vscodium", "fonts", "nvim"):
            (self.root / directory).symlink_to(REPO / directory, target_is_directory=True)
        result = self.run_script("install.sh", "--check", success=False, TEST_OLD_NVIM="1")
        self.assertIn("Neovim 0.12+", result.stderr)
        self.assertFalse(self.state.exists())
        self.assertFalse((self.state.parent / "logs").exists())
        self.assertFalse(any(call[0] == "sudo" for call in self.calls()))

    def test_existing_installation_is_not_overwritten(self):
        for directory in ("git", "zsh", "ghostty", "vscodium", "fonts", "nvim"):
            (self.root / directory).symlink_to(REPO / directory, target_is_directory=True)
        result = self.run_script("install.sh", success=False)
        self.assertIn("already recorded", result.stdout)
        self.assertEqual((self.state / "status").read_text(), "complete\n")
        self.assertFalse(any(call[0] == "sudo" for call in self.calls()))

    def test_install_stops_before_configs_when_neovim_is_old(self):
        shutil.rmtree(self.state)
        for directory in ("git", "zsh", "ghostty", "vscodium", "fonts", "nvim"):
            (self.root / directory).symlink_to(REPO / directory, target_is_directory=True)
        result = self.run_script("install.sh", success=False, TEST_OLD_NVIM="1")
        self.assertIn("Neovim 0.12+", result.stdout)
        self.assertEqual((self.state / "status").read_text(), "failed\n")
        self.assertEqual(list((self.state / "paths").iterdir()), [])
        self.assertIn("neovim.x86_64", (self.state / "packages.new").read_text())
        log = Path((self.state / "log-file").read_text().strip())
        self.assertIn("Neovim 0.12+", log.read_text())
        self.assertIn("Installation failed during: Checking installed commands and repository configs", log.read_text())
        self.run_script("uninstall.sh", "--keep-packages")
        self.assertTrue(log.exists())

    def test_log_captures_both_streams_and_keeps_failure_exit_status(self):
        result = self.shell('start_install_logging; step "Test failure"; printf "stdout marker\\n"; printf "stderr marker\\n" >&2; exit 23', success=False)
        self.assertEqual(result.returncode, 23)
        log = next((self.state.parent / "logs").glob("*.log"))
        content = log.read_text()
        for marker in ("stdout marker", "stderr marker", "Installation failed during: Test failure (exit 23)", "Installation ended with exit status 23", str(log)):
            self.assertIn(marker, content)
            self.assertIn(marker, result.stdout)
        self.assertRegex(content, r"\[\d{4}-\d{2}-\d{2}T.*\] ==> Test failure")
        self.assertEqual(log.stat().st_mode & 0o777, 0o600)
        # A failure before journal creation must not rewrite another installation's status.
        self.assertEqual((self.state / "status").read_text(), "complete\n")

    def test_successful_logs_are_flushed_and_unique_for_each_attempt(self):
        for marker in ("first attempt", "second attempt"):
            result = self.shell(f'start_install_logging; step "{marker}"; printf "final output\\n"')
            self.assertIn("Installation ended with exit status 0", result.stdout)
        logs = list((self.state.parent / "logs").glob("*.log"))
        self.assertEqual(len(logs), 2)
        for log in logs:
            self.assertIn("final output", log.read_text())
            self.assertIn("Installation ended with exit status 0", log.read_text())

    def test_logging_failure_is_reported_without_masking_install_error(self):
        tee = self.bin / "tee"
        tee.write_text('#!/usr/bin/env bash\n/usr/bin/tee "$@"\nexit 42\n')
        tee.chmod(0o755)
        for install_code, expected_code in ((0, 42), (23, 23)):
            with self.subTest(install_code=install_code):
                result = self.shell(f'start_install_logging; step "Log write failure"; exit {install_code}', success=False)
                self.assertEqual(result.returncode, expected_code)
                self.assertIn("Could not finish writing installation log", result.stderr)

    def test_interrupt_is_logged_and_marks_active_installation_failed(self):
        result = self.shell('start_install_logging; INSTALL_STATE_CREATED=true; step "Interrupted step"; kill -s INT "$$"', success=False)
        self.assertEqual(result.returncode, 130)
        log = next((self.state.parent / "logs").glob("*.log"))
        self.assertIn("Installation failed during: Interrupted step (exit 130)", log.read_text())
        self.assertEqual((self.state / "status").read_text(), "failed\n")


if __name__ == "__main__":
    unittest.main()
