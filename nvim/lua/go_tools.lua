local M = {}

function M.organize_imports(bufnr)
  bufnr = bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr, name = "gopls" })) do
    local params = vim.lsp.util.make_range_params(0, client.offset_encoding)
    params.context = { only = { "source.organizeImports" }, diagnostics = {} }
    local response, err = client:request_sync("textDocument/codeAction", params, 3000, bufnr)
    if err or (response and response.err) then
      vim.notify("gopls: could not organize imports: " .. vim.inspect(err or response.err), vim.log.levels.WARN)
      return
    end
    for _, action in ipairs(response and response.result or {}) do
      if action.edit then
        vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding)
      end
      if action.command then
        local command = type(action.command) == "table" and action.command or action
        client:request_sync("workspace/executeCommand", command, 3000, bufnr)
      end
    end
  end
end

function M.lint()
  local ok, lint = pcall(require, "lint")
  if not ok then
    return
  end
  if vim.bo.filetype ~= "go" then
    lint.try_lint()
    return
  end
  local filename = vim.api.nvim_buf_get_name(0)
  if vim.bo.buftype ~= "" or vim.bo.modified or vim.fn.filereadable(filename) == 0
    or vim.fn.executable("golangci-lint") == 0 then
    return
  end
  -- Run inside the package, even when Neovim was started outside the module.
  lint.try_lint("golangcilint", { cwd = vim.fs.dirname(filename) })
end

return M
