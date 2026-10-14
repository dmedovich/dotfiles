local capabilities = vim.lsp.protocol.make_client_capabilities()

local ok_blink, blink = pcall(require, "blink.cmp")
if ok_blink then
  capabilities = blink.get_lsp_capabilities(capabilities)
end

vim.lsp.config("lua_ls", {
  capabilities = capabilities,
  settings = {
    Lua = {
      diagnostics = {
        globals = { "vim" },
      },
      runtime = {
        version = "LuaJIT",
      },
      telemetry = {
        enable = false,
      },
      workspace = {
        checkThirdParty = false,
        library = vim.api.nvim_get_runtime_file("", true),
      },
    },
  },
})

vim.lsp.config("gopls", {
  capabilities = capabilities,
  -- Prefer the Go toolchain's gopls before Mason prepends its own bin directory.
  cmd = { vim.fn.exepath("gopls") ~= "" and vim.fn.exepath("gopls") or "gopls" },
  root_dir = function(bufnr, on_dir)
    local filename = vim.api.nvim_buf_get_name(bufnr)
    on_dir(vim.fs.root(filename, "go.work") or vim.fs.root(filename, "go.mod") or vim.fs.dirname(filename))
  end,
  settings = {
    gopls = {
      analyses = {
        nilness = true,
        shadow = true,
        unusedparams = true,
        unusedwrite = true,
      },
      gofumpt = true,
      completeUnimported = true,
      usePlaceholders = true,
      staticcheck = true,
    },
  },
})

vim.lsp.config("zls", {
  capabilities = capabilities,
  settings = {
    zls = {
      enable_inlay_hints = true,
    },
  },
})

local ok_mason, mason = pcall(require, "mason")
if ok_mason then
  mason.setup({
    -- Resolve metadata with client tooling, avoiding api.mason-registry.dev retries.
    providers = { "mason.providers.client" },
    ui = {
      border = "rounded",
    },
  })
end

local servers = { "lua_ls", "gopls", "zls" }

local ok_mason_lspconfig, mason_lspconfig = pcall(require, "mason-lspconfig")
if ok_mason_lspconfig then
  mason_lspconfig.setup({
    automatic_enable = false,
    ensure_installed = not vim.g.dotfiles_bootstrap and servers or {},
  })
end

-- Also enable servers installed outside Mason (for example by the installer).
if not vim.g.dotfiles_bootstrap then
  vim.lsp.enable(servers)
end
