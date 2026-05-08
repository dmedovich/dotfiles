-- ╔═══════════════════════════════════════╗
-- ║       honeynil — plugins/go           ║
-- ╚═══════════════════════════════════════╝

return {
  {
    "ray-x/go.nvim",
    dependencies = {
      "ray-x/guihua.lua",
      "neovim/nvim-lspconfig",
      "nvim-treesitter/nvim-treesitter",
    },
    ft    = { "go", "gomod", "gowork", "gotmpl" },
    build = ':lua require("go.install").update_all_sync()',
    config = function()
      require("go").setup({
        go           = "go",
        goimports    = "gopls",
        gofmt        = "gofumpt",
        max_line_len = 100,
        tag_transform = false,
        tag_options   = "json=omitempty",
        lsp_cfg            = false,
        lsp_gofumpt        = true,
        lsp_on_attach      = false,
        lsp_codelens       = false,
        lsp_inlay_hints    = { enable = false },
        diagnostic         = false,
        test_runner         = "go",
        run_in_floaterm     = true,
        floaterm            = {
          posititon = "auto",
          width     = 0.45,
          height    = 0.98,
          title_colors = "nord",
        },
        test_efm            = false,
        luasnip             = false,
        dap_debug           = true,
        dap_debug_keymap    = false,
        dap_debug_gui       = false,
        dap_debug_vt        = false,
        build_tags          = "",
        textobjects         = true,
        iferr_vertical_shift = 4,
      })
    end,
    keys = {
      { "<leader>gr", "<cmd>GoRun<cr>",            desc = "Go: Run" },
      { "<leader>gt", "<cmd>GoTestFile<cr>",       desc = "Go: Test file" },
      { "<leader>gT", "<cmd>GoTestFunc<cr>",       desc = "Go: Test func" },
      { "<leader>gc", "<cmd>GoCoverage<cr>",       desc = "Go: Coverage" },
      { "<leader>gC", "<cmd>GoCoverageToggle<cr>", desc = "Go: Coverage toggle" },
      { "<leader>gb", "<cmd>GoBuild<cr>",          desc = "Go: Build" },
      { "<leader>gi", "<cmd>GoImpl<cr>",           desc = "Go: Impl interface" },
      {
        "<leader>gf",
        function()
          require("conform").format({ async = true, lsp_fallback = true })
        end,
        desc = "Go: Format",
      },
      { "<leader>ga", "<cmd>GoAlt!<cr>",           desc = "Go: Alt (test<->src)" },
      { "<leader>gK", "<cmd>GoDoc<cr>",            desc = "Go: Doc" },
      { "<leader>gE", "<cmd>GoIfErr<cr>",          desc = "Go: Add if err" },
      { "<leader>gp", "<cmd>GoAddTag<cr>",         desc = "Go: Add struct tags" },
      { "<leader>gx", "<cmd>GoDebug<cr>",          desc = "Go: Debug" },
    },
  },

  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "leoluz/nvim-dap-go",
      {
        "rcarriga/nvim-dap-ui",
        dependencies = { "nvim-neotest/nvim-nio" },
      },
      "theHamsta/nvim-dap-virtual-text",
    },
    config = function()
      local dap     = require("dap")
      local dapui   = require("dapui")

      dap.listeners.after.event_initialized["dapui_config"] = function() dapui.open() end
      dap.listeners.before.event_terminated["dapui_config"] = function() dapui.close() end
      dap.listeners.before.event_exited["dapui_config"]     = function() dapui.close() end

      require("dap-go").setup({
        dap_configurations = {
          {
            type    = "go",
            name    = "Attach remote",
            mode    = "remote",
            request = "attach",
          },
        },
        delve = {
          path              = "dlv",
          initialize_timeout_sec = 20,
          port              = "${port}",
          args              = {},
          build_flags       = "",
          detached          = vim.fn.has("win32") == 0,
          cwd               = nil,
        },
      })

      require("nvim-dap-virtual-text").setup({
        enabled              = true,
        enabled_commands     = true,
        highlight_changed_variables = true,
        highlight_new_as_changed    = false,
        show_stop_reason     = true,
        commented            = false,
        virt_text_pos        = "eol",
        all_frames           = false,
        virt_lines           = false,
        virt_text_win_col    = nil,
      })

      dapui.setup({
        icons   = { expanded = "▾", collapsed = "▸", current_frame = "▸" },
        controls = {
          enabled    = true,
          element    = "repl",
          icons = {
            pause         = "",
            play          = "",
            step_into     = "",
            step_over     = "",
            step_out      = "",
            step_back     = "",
            run_last      = "",
            terminate     = "",
            disconnect    = "",
          },
        },
        floating = { border = "rounded", mappings = { close = { "q", "<Esc>" } } },
      })
    end,
    keys = {
      { "<leader>db", function() require("dap").toggle_breakpoint() end,              desc = "DAP: Breakpoint" },
      { "<leader>dc", function() require("dap").continue() end,                       desc = "DAP: Continue" },
      { "<leader>di", function() require("dap").step_into() end,                      desc = "DAP: Step into" },
      { "<leader>do", function() require("dap").step_over() end,                      desc = "DAP: Step over" },
      { "<leader>dO", function() require("dap").step_out() end,                       desc = "DAP: Step out" },
      { "<leader>dq", function() require("dap").terminate() end,                      desc = "DAP: Terminate" },
      { "<leader>du", function() require("dapui").toggle() end,                       desc = "DAP: UI Toggle" },
      { "<leader>de", function() require("dapui").eval() end, mode = { "n", "v" },    desc = "DAP: Eval" },
      { "<leader>dB", function()
          require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: "))
        end, desc = "DAP: Conditional breakpoint" },
      { "<leader>dl", function() require("dap-go").debug_last() end,                  desc = "DAP Go: Debug last" },
      { "<leader>dt", function() require("dap-go").debug_test() end,                  desc = "DAP Go: Debug test" },
    },
  },

  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "antoinemadec/FixCursorHold.nvim",
      "nvim-treesitter/nvim-treesitter",
      "fredrikaverpil/neotest-golang",
    },
    opts = function()
      return {
        adapters = {
          require("neotest-golang")({
            go_test_args     = { "-v", "-count=1", "-race", "-coverprofile=coverage.out" },
            dap_go_enabled   = true,
          }),
        },
        output      = { open_on_run = true },
        quickfix    = { open = function() vim.cmd("Trouble qflist open") end },
        status      = { virtual_text = true },
        icons = {
          passed  = " ",
          running = " ",
          failed  = " ",
          unknown = " ",
        },
      }
    end,
    keys = {
      { "<leader>tn", function() require("neotest").run.run() end,                          desc = "Neotest: Run nearest" },
      { "<leader>tf", function() require("neotest").run.run(vim.fn.expand("%")) end,         desc = "Neotest: Run file" },
      { "<leader>ta", function() require("neotest").run.run(vim.fn.getcwd()) end,            desc = "Neotest: Run all" },
      { "<leader>ts", function() require("neotest").summary.toggle() end,                   desc = "Neotest: Summary" },
      { "<leader>to", function() require("neotest").output_panel.toggle() end,              desc = "Neotest: Output" },
      { "<leader>td", function() require("neotest").run.run({ strategy = "dap" }) end,      desc = "Neotest: Debug" },
    },
  },
}
