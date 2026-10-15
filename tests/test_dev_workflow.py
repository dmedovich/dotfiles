"""Real Git indexes with stubbed scanner/test runner; never change user hooks."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]
CHECK = REPO / "scripts/dotfiles-check"
MOCK = '''#!/usr/bin/env python3
import json, os, pathlib, subprocess, sys
name = pathlib.Path(sys.argv[0]).name
with open(os.environ['CHECK_CALLS'], 'a') as f:
    f.write(json.dumps([name, *sys.argv[1:]]) + '\\n')
if name == 'gitleaks':
    staged = subprocess.check_output(['git', 'diff', '--cached'])
    sys.exit(1 if b'EXAMPLE_SECRET_FOR_TEST' in staged else 0)
if name == 'go':
    sources = list(pathlib.Path('.').rglob('*.go'))
    content = b''.join(p.read_bytes() for p in sources)
    pathlib.Path(os.environ['CHECK_SNAPSHOT']).write_bytes(content)
    sys.exit(1 if b'FAIL_STAGED' in content else 0)
'''


class DeveloperChecks(unittest.TestCase):
    def setUp(self):
        if not shutil.which("gofmt"):
            self.skipTest("gofmt is required")
        temp = tempfile.TemporaryDirectory(prefix="dotfiles-dev-test-")
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.project = self.root / "project with spaces"
        self.project.mkdir()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        for name in ("go", "gitleaks"):
            file = self.bin / name
            file.write_text(MOCK)
            file.chmod(0o755)
        self.env = dict(os.environ, PATH=str(self.bin) + ":" + os.environ["PATH"],
                        GIT_CONFIG_GLOBAL="/dev/null", GIT_CONFIG_SYSTEM="/dev/null",
                        CHECK_CALLS=str(self.root / "calls"), CHECK_SNAPSHOT=str(self.root / "snapshot"))
        for name in tuple(self.env):
            if name.startswith("GIT_") and name not in {"GIT_CONFIG_GLOBAL", "GIT_CONFIG_SYSTEM"}:
                self.env.pop(name)
        self.git("init", "-q")
        self.write("go.mod", "module example.com/check\n\ngo 1.27\n")
        self.write("main.go", "package main\n\nfunc main() {}\n")
        self.git("add", ".")

    def git(self, *args):
        return subprocess.check_output(["git", *args], cwd=self.project, env=self.env)

    def write(self, name, text):
        path = self.project / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)

    def check(self, *args):
        return subprocess.run([sys.executable, str(CHECK), *args], cwd=self.project,
                              env=self.env, text=True, capture_output=True, timeout=15)

    def calls(self):
        return [json.loads(line) for line in (self.root / "calls").read_text().splitlines()]

    def test_staged_snapshot_ignores_unstaged_edits_and_keeps_index(self):
        self.write("main.go", "package main\n\nfunc main() {} // FAIL_STAGED\n")
        before = self.git("diff", "--cached", "--binary")
        result = self.check()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn(b"FAIL_STAGED", (self.root / "snapshot").read_bytes())
        self.assertIn("FAIL_STAGED", (self.project / "main.go").read_text())
        self.assertEqual(self.git("diff", "--cached", "--binary"), before)

    def test_unformatted_staged_file_blocks_commit_without_changing_files(self):
        source = "package main\nfunc main(){println(1)}\n"
        self.write("main.go", source)
        self.git("add", "main.go")
        result = self.check()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Format these files", result.stderr)
        self.assertEqual((self.project / "main.go").read_text(), source)
        self.assertFalse(any(call[0] == "go" for call in self.calls()))

    def test_secret_scanner_failure_blocks_tests(self):
        self.write("example.txt", "EXAMPLE_SECRET_FOR_TEST\n")
        self.git("add", "example.txt")
        result = self.check()
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("EXAMPLE_SECRET_FOR_TEST", result.stderr)
        self.assertFalse(any(call[0] == "go" for call in self.calls()))
        self.assertIn("--redact", self.calls()[0])
        self.assertIn("--staged", self.calls()[0])

    def test_failing_staged_tests_block_commit(self):
        self.write("main.go", "package main\n\nfunc main() {} // FAIL_STAGED\n")
        self.git("add", "main.go")
        result = self.check()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("FAIL_STAGED", (self.root / "snapshot").read_text())

    def test_nested_module_runs_from_its_own_root(self):
        self.write("service/go.mod", "module example.com/service\n\ngo 1.27\n")
        self.write("service/api/api.go", "package api\n")
        self.git("add", ".")
        result = self.check()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(sum(call[0] == "go" for call in self.calls()), 2)

    def test_hook_installation_preserves_existing_hook(self):
        hook = self.project / ".git/hooks/pre-commit"
        hook.write_text("#!/bin/sh\necho existing\n")
        result = self.check("install")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("existing", hook.read_text())

    def test_hook_installation_respects_hooks_path(self):
        self.git("config", "core.hooksPath", "custom-hooks")
        result = self.check("install")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("core.hooksPath", result.stderr)

    def test_installed_hook_blocks_an_actual_commit(self):
        self.assertEqual(self.check("install").returncode, 0)
        self.write("example.txt", "EXAMPLE_SECRET_FOR_TEST\n")
        self.git("add", "example.txt")
        result = subprocess.run(["git", "-c", "user.name=Test", "-c", "user.email=test@example.com",
                                 "commit", "-m", "test"], cwd=self.project, env=self.env, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotEqual(subprocess.run(["git", "rev-parse", "--verify", "HEAD"], cwd=self.project,
                                          env=self.env, capture_output=True).returncode, 0)
