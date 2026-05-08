-- ╔══════════════════════════════════════╗
-- ║     honeynil — plugins/editor        ║
-- ╚══════════════════════════════════════╝

return {
  {
    "nvim-treesitter/nvim-treesitter",
    build  = ":TSUpdate",
    event  = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "nvim-treesitter/nvim-treesitter-textobjects",
      "nvim-treesitter/nvim-treesitter-context",
    },
    opts = {
      ensure_installed = {
        "go", "gomod", "gowork", "gosum",
        "lua", "luadoc", "vim", "vimdoc", "query",
        "bash", "fish",
        "json", "jsonc", "yaml", "toml",
        "dockerfile", "sql",
        "markdown", "markdown_inline",
        "regex", "comment",
        "proto",
      },
      auto_install   = true,
      highlight      = { enable = true, additional_vim_regex_highlighting = false },
      indent         = { enable = true },
      incremental_selection = {
        enable  = true,
        keymaps = {
          init_selection    = "<C-space>",
          node_incremental  = "<C-space>",
          scope_incremental = false,
          node_decremental  = "<bs>",
        },
      },
      textobjects = {
        select = {
          enable    = true,
          lookahead = true,
          keymaps   = {
            ["af"] = "@function.outer",
            ["if"] = "@function.inner",
            ["ac"] = "@class.outer",
            ["ic"] = "@class.inner",
            ["as"] = "@block.outer",
            ["is"] = "@block.inner",
            ["aa"] = "@parameter.outer",
            ["ia"] = "@parameter.inner",
          },
        },
        move = {
          enable    = true,
          set_jumps = true,
          goto_next_start     = { ["]f"] = "@function.outer", ["]c"] = "@class.outer" },
          goto_next_end       = { ["]F"] = "@function.outer", ["]C"] = "@class.outer" },
          goto_previous_start = { ["[f"] = "@function.outer", ["[c"] = "@class.outer" },
          goto_previous_end   = { ["[F"] = "@function.outer", ["[C"] = "@class.outer" },
        },
        swap = {
          enable       = true,
          swap_next     = { ["<leader>ap"] = "@parameter.inner" },
          swap_previous = { ["<leader>aP"] = "@parameter.inner" },
        },
      },
    },
  },

  {
    "nvim-treesitter/nvim-treesitter-context",
    event = "VeryLazy",
    opts = {
      enable         = true,
      max_lines      = 3,
      trim_scope     = "outer",
      mode           = "cursor",
      separator      = nil,
      zindex         = 20,
    },
  },

  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      icons = { mappings = true },
      spec  = {
        { "<leader>g",  group = " Go / Git" },
        { "<leader>l",  group = "󰒕 LSP" },
        { "<leader>f",  group = " Find" },
        { "<leader>h",  group = " Git hunks" },
        { "<leader>d",  group = " Debug" },
        { "<leader>t",  group = "󰙨 Test" },
        { "<leader>b",  group = " Buffer" },
      },
    },
  },

  {
    "lukas-reineke/indent-blankline.nvim",
    event = { "BufReadPost", "BufNewFile" },
    main  = "ibl",
    opts  = {
      indent  = { char = "│", tab_char = "│" },
      scope   = { enabled = true, show_start = true, show_end = false },
      exclude = {
        filetypes = {
          "help", "alpha", "dashboard", "neo-tree", "Trouble", "trouble",
          "lazy", "mason", "notify", "toggleterm", "lazyterm",
        },
      },
    },
  },

  {
    "windwp/nvim-autopairs",
    event  = "InsertEnter",
    opts = {
      check_ts          = true,
      ts_config         = { lua = { "string" }, go = { "string" } },
      disable_filetype  = { "TelescopePrompt", "spectre_panel" },
      fast_wrap = {
        map         = "<M-e>",
        chars       = { "{", "[", "(", '"', "'" },
        pattern     = [=[[%'%"%>%]%)%}%,]]=],
        end_key     = "$",
        keys        = "qwertyuiopzxcvbnmasdfghjkl",
        check_comma = true,
        highlight   = "PmenuSel",
        highlight_grey = "LineNr",
      },
    },
    config = function(_, opts)
      local autopairs = require("nvim-autopairs")
      autopairs.setup(opts)
      vim.schedule(function()
        local ok, cmp = pcall(require, "cmp")
        if ok then
          local cmp_autopairs = require("nvim-autopairs.completion.cmp")
          cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
        end
      end)
    end,
  },

  {
    "numToStr/Comment.nvim",
    event = { "BufReadPost", "BufNewFile" },
    opts  = {
      padding  = true,
      sticky   = true,
      ignore   = "^$",
      toggler  = { line = "gcc", block = "gbc" },
      opleader = { line = "gc",  block = "gb" },
      mappings = { basic = true, extra = true },
    },
  },

  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts  = {
      modes = {
        search   = { enabled = false },
        char     = { enabled = true, jump_labels = true },
      },
    },
    keys = {
      { "s",     mode = { "n", "x", "o" }, function() require("flash").jump() end,              desc = "Flash" },
      { "S",     mode = { "n", "x", "o" }, function() require("flash").treesitter() end,        desc = "Flash Treesitter" },
      { "r",     mode = "o",               function() require("flash").remote() end,             desc = "Remote Flash" },
      { "R",     mode = { "o", "x" },      function() require("flash").treesitter_search() end, desc = "Flash TS Search" },
      { "<C-s>", mode = { "c" },           function() require("flash").toggle() end,             desc = "Flash Cmdline" },
    },
  },

  {
    "folke/todo-comments.nvim",
    cmd      = { "TodoTrouble", "TodoTelescope" },
    event    = { "BufReadPost", "BufNewFile" },
    opts     = {
      signs      = true,
      sign_priority = 8,
      keywords = {
        FIX    = { icon = " ", color = "error",   alt = { "FIXME", "BUG", "FIXIT", "ISSUE" } },
        TODO   = { icon = " ", color = "info" },
        HACK   = { icon = " ", color = "warning" },
        WARN   = { icon = " ", color = "warning", alt = { "WARNING", "XXX" } },
        PERF   = { icon = "󰾆 ", alt = { "OPTIM", "PERFORMANCE", "OPTIMIZE" } },
        NOTE   = { icon = "󰋽 ", color = "hint",    alt = { "INFO" } },
        TEST   = { icon = "⏲ ", color = "test",    alt = { "TESTING", "PASSED", "FAILED" } },
      },
      highlight = {
        multiline          = true,
        before             = "",
        keyword            = "wide",
        after              = "fg",
        pattern            = [[.*<(KEYWORDS)\s*:]],
        comments_only      = true,
        max_line_len       = 400,
        exclude            = {},
      },
    },
    keys = {
      { "]t",         function() require("todo-comments").jump_next() end, desc = "Next todo comment" },
      { "[t",         function() require("todo-comments").jump_prev() end, desc = "Prev todo comment" },
      { "<leader>ft", "<cmd>TodoTelescope<cr>",                            desc = "Find todos" },
    },
  },

  {
    "folke/trouble.nvim",
    cmd  = "Trouble",
    opts = {
      modes = {
        lsp = {
          win = { position = "right" },
        },
      },
    },
    keys = {
      { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>",                        desc = "Diagnostics (Trouble)" },
      { "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>",           desc = "Buffer diagnostics" },
      { "<leader>cs", "<cmd>Trouble symbols toggle focus=false<cr>",                desc = "Symbols (Trouble)" },
      { "<leader>cl", "<cmd>Trouble lsp toggle focus=false win.position=right<cr>", desc = "LSP info (Trouble)" },
      { "<leader>xL", "<cmd>Trouble loclist toggle<cr>",                            desc = "Location list" },
      { "<leader>xQ", "<cmd>Trouble qflist toggle<cr>",                             desc = "Quickfix list" },
    },
  },
}
