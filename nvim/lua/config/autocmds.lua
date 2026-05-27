local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

autocmd("TextYankPost", {
  group    = augroup("honeynil_yank", { clear = true }),
  callback = function()
    vim.highlight.on_yank({ higroup = "IncSearch", timeout = 150 })
  end,
})

autocmd("FileType", {
  group   = augroup("honeynil_go", { clear = true }),
  pattern = "go",
  callback = function()
    vim.opt_local.tabstop     = 4
    vim.opt_local.shiftwidth  = 4
    vim.opt_local.expandtab   = false
  end,
})

autocmd("LspAttach", {
  group = augroup("honeynil_lsp_attach", { clear = true }),
  callback = function(args)
    local map = function(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = args.buf, desc = desc })
    end

    map("n", "gd", vim.lsp.buf.definition, "LSP: Go to definition")
    map("n", "gD", vim.lsp.buf.declaration, "LSP: Go to declaration")
    map("n", "gi", vim.lsp.buf.implementation, "LSP: Implementation")
    map("n", "gr", vim.lsp.buf.references, "LSP: References")
    map("n", "K", vim.lsp.buf.hover, "LSP: Hover docs")
    map("n", "<leader>ca", vim.lsp.buf.code_action, "LSP: Code action")
    map("n", "<leader>rn", vim.lsp.buf.rename, "LSP: Rename")
    map("n", "<leader>lD", vim.diagnostic.open_float, "LSP: Line diagnostics")
    map("n", "[d", function()
      vim.diagnostic.goto_prev({ float = { border = "rounded" } })
    end, "Prev diagnostic")
    map("n", "]d", function()
      vim.diagnostic.goto_next({ float = { border = "rounded" } })
    end, "Next diagnostic")
  end,
})

autocmd("FileType", {
  group   = augroup("honeynil_close_q", { clear = true }),
  pattern = { "help", "man", "qf", "notify", "lspinfo" },
  callback = function()
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = true, silent = true })
  end,
})

autocmd("BufReadPost", {
  group = augroup("honeynil_restore_cursor", { clear = true }),
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})
