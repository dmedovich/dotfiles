vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.cmd("filetype plugin indent on")
vim.cmd("syntax enable")

local opt = vim.opt

opt.autoread = true
opt.breakindent = true
opt.clipboard = "unnamedplus"
opt.completeopt = { "menu", "menuone", "noselect" }
opt.cursorline = true
opt.expandtab = true
opt.ignorecase = true
opt.inccommand = "split"
opt.linebreak = true
opt.mouse = "a"
opt.number = true
opt.relativenumber = true
opt.scrolloff = 8
opt.shiftwidth = 4
opt.showmode = false
opt.signcolumn = "yes"
opt.smartcase = true
opt.smartindent = true
opt.splitbelow = true
opt.splitright = true
opt.swapfile = false
opt.tabstop = 4
opt.termguicolors = true
opt.undofile = true
opt.updatetime = 250
opt.wrap = false

opt.background = "dark"
pcall(vim.cmd.colorscheme, "habamax")

vim.diagnostic.config({
  float = { border = "rounded" },
  severity_sort = true,
  underline = true,
  update_in_insert = false,
  virtual_text = {
    prefix = "*",
    spacing = 2,
  },
})
