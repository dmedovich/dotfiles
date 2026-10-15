"""Use real Neovim error handling with offline plugin/installer fixtures."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]
SERVERS = ("lua-language-server", "gopls", "zls")
INIT = r'''
local root = vim.env.TEST_MASON_ROOT
for _, name in ipairs({ "lualine", "mason", "mason-lspconfig", "neo-tree", "plenary",
  "nui.popup", "nvim-web-devicons", "blink.cmp", "fzf-lua", "which-key", "gitsigns",
  "conform", "Comment", "nvim-autopairs", "lint", "ibl", "todo-comments", "diffview", "neogit",
  "dap", "nio", "dapui", "dap-go", "neotest", "neotest-go", "persistence" }) do
  package.preload[name] = function() return {} end
end
package.preload["nvim-treesitter"] = function()
  return { install = function() return { wait = function() return true end } end }
end
package.preload["mason.settings"] = function()
  return { current = { install_root_dir = root } }
end
package.preload["mason-registry"] = function()
  return { is_installed = function(name) return vim.fn.isdirectory(root .. "/packages/" .. name) == 1 end }
end
vim.treesitter.language.add = function() return true end
vim.api.nvim_create_user_command("MasonInstall", function(opts)
  assert(vim.env.TEST_FORBID_INSTALL ~= "1", "Existing servers must not be reinstalled")
  local quiet = false
  for _, arg in ipairs(opts.fargs) do if arg == "--quiet" then quiet = true end end
  -- This is Mason's default stderr handler. Go routinely writes progress here
  -- even when installation succeeds; nvim_exec2 treats it as a command error.
  if not quiet then vim.api.nvim_err_write("go: downloading golang.org/x/tools v0.23.0\n") end
  for _, name in ipairs(opts.fargs) do
    if name ~= "--quiet" then
      local package = root .. "/packages/" .. name
      vim.fn.mkdir(package, "p")
      vim.fn.mkdir(root .. "/bin", "p")
      vim.fn.writefile({ "#!/bin/sh", "exit 0" }, root .. "/bin/" .. name)
      vim.uv.fs_chmod(root .. "/bin/" .. name, 493)
      if name ~= vim.env.TEST_MISSING_RECEIPT then
        vim.fn.writefile({ "{}" }, package .. "/mason-receipt.json")
      end
    end
  end
end, { nargs = "+" })
'''


class Bootstrap(unittest.TestCase):
    def setUp(self):
        self.nvim = shutil.which("nvim", path="/usr/bin:/bin")
        if not self.nvim:
            self.skipTest("A system Neovim is needed for the offline bootstrap tests")
        temp = tempfile.TemporaryDirectory(prefix=".bootstrap-test-", dir=REPO)
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.init = self.root / "init.lua"
        self.init.write_text(INIT)
        (self.root / "lsp").mkdir()
        (self.root / "lsp/gopls.lua").write_text("return {}\n")
        self.mason = self.root / "mason"
        self.env = dict(os.environ, NVIM_LOG_FILE="/dev/null", NVIM_APPNAME="nvim",
                        DOTFILES_NVIM_INIT=str(self.init), TEST_MASON_ROOT=str(self.mason))
        for key in ("CONFIG", "DATA", "STATE", "CACHE"):
            self.env[f"XDG_{key}_HOME"] = str(self.root / key.lower())

    def run_bootstrap(self, **extra):
        return subprocess.run(
            [self.nvim, "--headless", "-u", "NONE", "-i", "NONE", "--cmd", "set loadplugins", "-l", str(REPO / "scripts/bootstrap-nvim.lua")],
            cwd=self.root, env=self.env | extra, text=True, capture_output=True, timeout=20,
        )

    def test_successful_installation_does_not_turn_go_progress_into_a_vim_error(self):
        result = self.run_bootstrap()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("language servers verified", result.stdout + result.stderr)
        for name in SERVERS:
            self.assertTrue((self.mason / "packages" / name / "mason-receipt.json").exists())

    def test_successful_servers_from_previous_attempt_are_not_downloaded_again(self):
        first = self.run_bootstrap()
        self.assertEqual(first.returncode, 0, first.stdout + first.stderr)
        second = self.run_bootstrap(TEST_FORBID_INSTALL="1")
        self.assertEqual(second.returncode, 0, second.stdout + second.stderr)

    def test_development_plugins_are_verified_for_the_new_config(self):
        (self.root / "lua").mkdir()
        (self.root / "lua/development.lua").write_text("return {}\n")
        result = self.run_bootstrap()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_missing_development_plugin_fails_for_the_new_config(self):
        (self.root / "lua").mkdir()
        (self.root / "lua/development.lua").write_text("return {}\n")
        with self.init.open("a") as init:
            init.write('package.preload["dapui"] = nil\n')
        result = self.run_bootstrap()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("dapui", result.stdout + result.stderr)

    def test_partial_installation_without_receipt_still_fails(self):
        result = self.run_bootstrap(TEST_MISSING_RECEIPT="gopls")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("installation is incomplete", result.stdout + result.stderr)

    def test_original_mason_stderr_handler_reproduces_reported_failure(self):
        control = self.root / "control.lua"
        control.write_text('vim.cmd("MasonInstall lua-language-server gopls zls")\n')
        result = subprocess.run(
            [self.nvim, "--headless", "-u", str(self.init), "-i", "NONE", "-l", str(control)],
            cwd=self.root, env=self.env, text=True, capture_output=True, timeout=20,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("go: downloading", result.stdout + result.stderr)
        self.assertTrue((self.mason / "packages/gopls/mason-receipt.json").exists())
