local map = vim.keymap.set

map("n", "<leader>q",  "<cmd>qa<cr>",              { desc = "Quit all" })
map("n", "<Esc>",      "<cmd>nohlsearch<cr><Esc>", { desc = "Clear search" })
map("n", "<leader>w",  "<cmd>w<cr>",               { desc = "Save" })

map({ "n", "x" }, "j", "gj")
map({ "n", "x" }, "k", "gk")

map("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move line down" })
map("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move line up" })

map("n", "<leader>|", "<cmd>vsplit<cr>",  { desc = "Vertical split" })
map("n", "<leader>-", "<cmd>split<cr>",   { desc = "Horizontal split" })

map("n", "<C-h>", "<C-w>h", { desc = "Window left" })
map("n", "<C-j>", "<C-w>j", { desc = "Window down" })
map("n", "<C-k>", "<C-w>k", { desc = "Window up" })
map("n", "<C-l>", "<C-w>l", { desc = "Window right" })

map("n", "<C-Up>",    "<cmd>resize +2<cr>")
map("n", "<C-Down>",  "<cmd>resize -2<cr>")
map("n", "<C-Left>",  "<cmd>vertical resize -2<cr>")
map("n", "<C-Right>", "<cmd>vertical resize +2<cr>")

map("n", "<S-h>",      "<cmd>bprevious<cr>",    { desc = "Prev buffer" })
map("n", "<S-l>",      "<cmd>bnext<cr>",         { desc = "Next buffer" })
map("n", "<leader>bd", "<cmd>bdelete<cr>",       { desc = "Delete buffer" })

map("n", "<leader>ff", "<cmd>Telescope find_files<cr>",   { desc = "Find files" })
map("n", "<leader>fg", "<cmd>Telescope live_grep<cr>",    { desc = "Live grep" })
map("n", "<leader>fb", "<cmd>Telescope buffers<cr>",      { desc = "Buffers" })
map("n", "<leader>fh", "<cmd>Telescope help_tags<cr>",    { desc = "Help tags" })
map("n", "<leader>fs", "<cmd>Telescope lsp_document_symbols<cr>", { desc = "Symbols" })
map("n", "<leader>fr", "<cmd>Telescope oldfiles<cr>",     { desc = "Recent files" })
map("n", "<leader>fc", "<cmd>Telescope git_commits<cr>",  { desc = "Git commits" })
map("n", "<leader>fd", "<cmd>Telescope diagnostics<cr>",  { desc = "Diagnostics" })
