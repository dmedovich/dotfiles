local map = vim.keymap.set

map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })
map("n", "<leader>w", "<cmd>write<CR>", { desc = "Write file" })
map("n", "<leader>q", "<cmd>quit<CR>", { desc = "Quit window" })
map("n", "<leader>lf", function()
  local ok, conform = pcall(require, "conform")
  if ok then
    conform.format({
      async = true,
      lsp_format = "fallback",
    })
    return
  end

  vim.lsp.buf.format({ async = true })
end, { desc = "Format buffer" })
map("n", "<leader>ll", function()
  local ok, lint = pcall(require, "lint")
  if ok then
    lint.try_lint()
  end
end, { desc = "Run lint" })
map("n", "<leader>t", function()
  vim.cmd("botright 12split")
  vim.cmd("terminal")
  vim.cmd("startinsert")
end, { desc = "Open terminal" })

map("n", "<leader>e", "<cmd>Neotree toggle<CR>", { desc = "Toggle file tree" })
map("n", "<leader>o", "<cmd>Neotree focus<CR>", { desc = "Focus file tree" })

map("n", "<leader>ff", function()
  require("fzf-lua").files()
end, { desc = "Find files" })

map("n", "<leader>fg", function()
  require("fzf-lua").live_grep()
end, { desc = "Live grep" })

map("n", "<leader>fb", function()
  require("fzf-lua").buffers()
end, { desc = "Find buffers" })

map("n", "<leader>fh", function()
  require("fzf-lua").helptags()
end, { desc = "Find help" })

map("n", "<leader>fr", function()
  require("fzf-lua").oldfiles()
end, { desc = "Recent files" })

map("n", "<leader>fd", function()
  require("fzf-lua").diagnostics_document()
end, { desc = "Document diagnostics" })

map("n", "<leader>ft", "<cmd>TodoFzfLua<CR>", { desc = "Find TODOs" })
map("n", "<leader>fT", "<cmd>TodoQuickFix<CR>", { desc = "TODO quickfix" })

map("n", "]t", function()
  require("todo-comments").jump_next()
end, { desc = "Next TODO comment" })

map("n", "[t", function()
  require("todo-comments").jump_prev()
end, { desc = "Previous TODO comment" })

map("n", "<leader>gg", "<cmd>Neogit<CR>", { desc = "Git status UI" })
map("n", "<leader>gd", "<cmd>DiffviewOpen<CR>", { desc = "Git diff view" })
map("n", "<leader>gD", "<cmd>DiffviewClose<CR>", { desc = "Close diff view" })
map("n", "<leader>gh", "<cmd>DiffviewFileHistory %<CR>", { desc = "Current file history" })
map("n", "<leader>gH", "<cmd>DiffviewFileHistory<CR>", { desc = "Repo file history" })

map("n", "<leader>gs", function()
  require("fzf-lua").git_status()
end, { desc = "Git status files" })

map("n", "<leader>gb", function()
  require("fzf-lua").git_branches()
end, { desc = "Git branches" })

map("n", "<leader>gc", function()
  require("fzf-lua").git_commits()
end, { desc = "Git commits" })

map("n", "<leader>gC", function()
  require("fzf-lua").git_bcommits()
end, { desc = "Current file commits" })
