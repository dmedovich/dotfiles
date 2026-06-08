local augroup = vim.api.nvim_create_augroup("user_config", { clear = true })

vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
  group = augroup,
  pattern = "*.go",
  callback = function()
    vim.cmd("setfiletype go")
  end,
})

vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
  group = augroup,
  callback = function()
    if vim.bo.buftype == "" then
      vim.opt_local.number = true
      vim.opt_local.relativenumber = true
    end
  end,
})

vim.api.nvim_create_autocmd("TextYankPost", {
  group = augroup,
  callback = function()
    vim.highlight.on_yank({ timeout = 150 })
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = augroup,
  pattern = { "lua", "zig" },
  callback = function()
    vim.opt_local.expandtab = true
    vim.opt_local.shiftwidth = 2
    vim.opt_local.tabstop = 2
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = augroup,
  pattern = { "go", "gomod", "gowork", "gotmpl" },
  callback = function()
    vim.opt_local.expandtab = false
    vim.opt_local.shiftwidth = 4
    vim.opt_local.tabstop = 4
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = augroup,
  pattern = { "go", "gomod", "gosum", "gowork", "lua", "vim", "zig" },
  callback = function(event)
    pcall(vim.treesitter.start, event.buf)
  end,
})

vim.api.nvim_create_autocmd("LspAttach", {
  group = augroup,
  callback = function(event)
    local bufnr = event.buf
    local map = function(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
    end

    map("n", "K", vim.lsp.buf.hover, "LSP hover")
    map("n", "gd", vim.lsp.buf.definition, "LSP definition")
    map("n", "gD", vim.lsp.buf.declaration, "LSP declaration")
    map("n", "gi", vim.lsp.buf.implementation, "LSP implementation")
    map("n", "gr", vim.lsp.buf.references, "LSP references")
    map("n", "<leader>ca", vim.lsp.buf.code_action, "LSP code action")
    map("n", "<leader>rn", vim.lsp.buf.rename, "LSP rename")
    map("n", "<leader>ls", function()
      require("fzf-lua").lsp_document_symbols()
    end, "LSP document symbols")
    map("n", "<leader>lS", function()
      require("fzf-lua").lsp_workspace_symbols()
    end, "LSP workspace symbols")

    local client = vim.lsp.get_client_by_id(event.data.client_id)
    if client and client:supports_method("textDocument/inlayHint") then
      vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
    end
  end,
})
