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
  settings = {
    gopls = {
      analyses = {
        nilness = true,
        shadow = true,
        unusedparams = true,
        unusedwrite = true,
      },
      gofumpt = true,
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
    ui = {
      border = "rounded",
    },
  })
end

local servers = { "lua_ls", "gopls", "zls" }

local ok_mason_lspconfig, mason_lspconfig = pcall(require, "mason-lspconfig")
if ok_mason_lspconfig then
  mason_lspconfig.setup({
    automatic_enable = servers,
    ensure_installed = servers,
  })
else
  vim.lsp.enable(servers)
end
