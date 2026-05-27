local opt = vim.opt

opt.termguicolors  = true
opt.number         = true
opt.relativenumber = true
opt.signcolumn     = "yes"
opt.cursorline     = true
opt.scrolloff      = 8
opt.sidescrolloff  = 8
opt.wrap           = false
opt.colorcolumn    = "100"
opt.cmdheight      = 1
opt.showmode       = false
opt.pumheight      = 12
opt.splitright     = true
opt.splitbelow     = true

opt.tabstop      = 4
opt.shiftwidth   = 4
opt.softtabstop  = 4
opt.expandtab    = false
opt.autoindent   = true
opt.smartindent  = true

opt.ignorecase  = true
opt.smartcase   = true
opt.hlsearch    = true
opt.incsearch   = true

opt.undofile    = true
opt.swapfile    = false
opt.backup      = false
opt.updatetime  = 200
opt.timeoutlen  = 300

opt.completeopt = { "menu", "menuone", "noselect" }
opt.shortmess:append("c")

opt.foldmethod    = "expr"
opt.foldexpr      = "nvim_treesitter#foldexpr()"
opt.foldenable    = false
opt.foldlevel     = 99

opt.mouse       = "a"
opt.clipboard   = "unnamedplus"
opt.laststatus  = 3
opt.list        = true
opt.listchars   = { tab = "> ", trail = ".", nbsp = "_" }

vim.g.mapleader       = " "
vim.g.maplocalleader  = "\\"
vim.g.lazyvim_cmp     = "nvim-cmp"
vim.g.lazyvim_explorer = "neo-tree"
