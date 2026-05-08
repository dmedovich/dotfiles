-- ╔══════════════════════════════════════╗
-- ║       honeynil — plugins/lsp         ║
-- ╚══════════════════════════════════════╝

return {
  {
    "mason-org/mason.nvim",
    opts = {
      ui = {
        border = "rounded",
        icons  = {
          package_installed   = "✓",
          package_pending     = "➜",
          package_uninstalled = "✗",
        },
      },
      ensure_installed = {
        -- Go
        "gopls",
        "goimports",
        "gofumpt",
        "golangci-lint",
        "delve",         -- Go debugger
        "gomodifytags",
        "gotests",
        "impl",
        -- General
        "lua-language-server",
        "stylua",
        "json-lsp",
        "yaml-language-server",
        "dockerfile-language-server",
        "bash-language-server",
        "markdownlint",
      },
    },
  },

  {
    "neovim/nvim-lspconfig",
    opts = {
      diagnostics = {
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = " ",
            [vim.diagnostic.severity.WARN]  = " ",
            [vim.diagnostic.severity.HINT]  = "󰠠 ",
            [vim.diagnostic.severity.INFO]  = " ",
          },
        },
        underline       = true,
        update_in_insert = false,
        virtual_text    = {
          spacing = 4,
          source  = "if_many",
          prefix  = "●",
        },
        severity_sort   = true,
        float = {
          border = "rounded",
          source = true,
        },
      },
      inlay_hints = { enabled = true },
      servers = {
        gopls = {
          settings = {
            gopls = {
              gofumpt        = true,
              codelenses = {
                gc_details    = false,
                generate      = true,
                regenerate_cgo = true,
                run_govulncheck = true,
                test          = true,
                tidy          = true,
                upgrade_dependency = true,
                vendor        = true,
              },
              hints = {
                assignVariableTypes    = true,
                compositeLiteralFields = true,
                compositeLiteralTypes  = true,
                constantValues         = true,
                functionTypeParameters = true,
                parameterNames         = true,
                rangeVariableTypes     = true,
              },
              analyses = {
                fieldalignment = true,
                nilness        = true,
                unusedparams   = true,
                unusedwrite    = true,
                useany         = true,
              },
              usePlaceholders    = true,
              completeUnimported = true,
              staticcheck        = true,
              directoryFilters   = {
                "-.git", "-.vscode", "-.idea",
                "-node_modules", "-vendor",
              },
              semanticTokens = true,
            },
          },
        },

        lua_ls = {
          settings = {
            Lua = {
              workspace = { checkThirdParty = false },
              telemetry = { enable = false },
              hint      = { enable = true },
            },
          },
        },

        yamlls = {
          settings = {
            yaml = {
              keyOrdering = false,
              schemas = {
                ["https://json.schemastore.org/github-workflow.json"] = "/.github/workflows/*",
                ["https://raw.githubusercontent.com/compose-spec/compose-spec/master/schema/compose-spec.json"] = "*docker-compose*.yml",
              },
            },
          },
        },

        jsonls     = {},
        dockerls   = {},
        bashls     = {},
      },
    },
  },

  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd   = { "ConformInfo" },
    opts = {
      formatters_by_ft = {
        go  = { "goimports", "gofumpt" },
        lua = { "stylua" },
        sh  = { "shfmt" },
        json = { "prettier" },
        yaml = { "prettier" },
        markdown = { "prettier" },
      },
      format_on_save = {
        lsp_fallback = true,
        async        = false,
        timeout_ms   = 3000,
      },
    },
    keys = {
      {
        "<leader>lf",
        function() require("conform").format({ async = true, lsp_fallback = true }) end,
        desc = "Format buffer",
      },
    },
  },

  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local lint = require("lint")
      lint.linters_by_ft = {
        go = { "golangcilint" },
      }
      local group = vim.api.nvim_create_augroup("honeynil_lint", { clear = true })
      vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost" }, {
        group = group,
        pattern = "*.go",
        callback = function()
          lint.try_lint()
        end,
      })
    end,
  },
}
