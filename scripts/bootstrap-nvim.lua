-- Run with -u NONE -l so startup errors propagate as a non-zero process exit.
local init = assert(vim.env.DOTFILES_NVIM_INIT, "DOTFILES_NVIM_INIT is missing")
vim.g.dotfiles_bootstrap = true
vim.opt.runtimepath:prepend(vim.fn.fnamemodify(init, ":h"))
vim.cmd.source(vim.fn.fnameescape(init))

for _, module in ipairs({
  "lualine", "mason", "mason-lspconfig", "neo-tree", "plenary",
  "nui.popup", "nvim-web-devicons", "nvim-treesitter", "blink.cmp", "fzf-lua",
  "which-key", "gitsigns", "conform", "Comment", "nvim-autopairs", "lint",
  "ibl", "todo-comments", "diffview", "neogit",
}) do
  assert(require(module), "Plugin could not be loaded: " .. module)
end

assert(#vim.api.nvim_get_runtime_file("lsp/gopls.lua", false) > 0, "nvim-lspconfig server definitions are missing")
local parsers = { "go", "gomod", "gosum", "gowork", "lua", "luadoc", "query", "vim", "vimdoc", "zig" }
require("nvim-treesitter").install(parsers):wait(300000)
for _, parser in ipairs(parsers) do
  assert(vim.treesitter.language.add(parser), "Parser could not be loaded: " .. parser)
end

-- MasonInstall blocks in headless mode; verify every receipt afterwards.
vim.cmd("MasonInstall lua-language-server gopls zls")
local registry = require("mason-registry")
for _, name in ipairs({ "lua-language-server", "gopls", "zls" }) do
  assert(registry.is_installed(name), "Mason installation failed: " .. name)
end
for _, name in ipairs({ "lua-language-server", "gopls", "zls" }) do
  assert(vim.fn.executable(name) == 1, "Language server is not executable: " .. name)
end
assert(vim.v.errmsg == "", vim.v.errmsg)
print("Neovim plugins, parsers and language servers verified")
