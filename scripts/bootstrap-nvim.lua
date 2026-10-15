-- Run with -u NONE -l so startup errors propagate as a non-zero process exit.
local init = assert(vim.env.DOTFILES_NVIM_INIT, "DOTFILES_NVIM_INIT is missing")
vim.env.MASON_VERBOSE_LOGS = "1"
vim.g.dotfiles_bootstrap = true
print("Neovim: loading config and plugins")
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

-- A resumed installation may still have the previous config without these plugins.
if vim.fn.filereadable(vim.fn.fnamemodify(init, ":h") .. "/lua/development.lua") == 1 then
  for _, module in ipairs({ "dap", "nio", "dapui", "dap-go", "neotest", "neotest-go", "persistence" }) do
    assert(require(module), "Plugin could not be loaded: " .. module)
  end
end

assert(#vim.api.nvim_get_runtime_file("lsp/gopls.lua", false) > 0, "nvim-lspconfig server definitions are missing")
print("Neovim: plugins loaded; installing Treesitter parsers")
local parsers = { "go", "gomod", "gosum", "gowork", "lua", "luadoc", "query", "vim", "vimdoc", "zig" }
assert(require("nvim-treesitter").install(parsers):wait(300000), "Treesitter parser installation failed")
for _, parser in ipairs(parsers) do
  assert(vim.treesitter.language.add(parser), "Parser could not be loaded: " .. parser)
end

-- MasonInstall blocks in headless mode. Its default stderr handler treats normal
-- Go download progress as a Vim error, so suppress command streams and verify
-- receipts/binaries instead. Mason's own progress logging remains enabled.
print("Neovim: Treesitter parsers verified; installing Mason language servers")
print("Mason log: " .. vim.fn.stdpath("log") .. "/mason.log")
local registry = require("mason-registry")
local mason_root = require("mason.settings").current.install_root_dir
local servers = { "lua-language-server", "gopls", "zls" }
local function installed(name)
  return registry.is_installed(name)
    and vim.fn.filereadable(mason_root .. "/packages/" .. name .. "/mason-receipt.json") == 1
    and vim.fn.executable(mason_root .. "/bin/" .. name) == 1
end
local missing = {}
for _, name in ipairs(servers) do
  if not installed(name) then missing[#missing + 1] = name end
end
if #missing > 0 then
  vim.cmd("MasonInstall --quiet " .. table.concat(missing, " "))
end
for _, name in ipairs(servers) do
  assert(installed(name), "Mason installation is incomplete (receipt or executable missing): " .. name)
  print("Mason: verified " .. name)
end
print("Neovim plugins, parsers and language servers verified")
