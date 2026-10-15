local M = {}

function M.setup()
  local dap, dapui = require("dap"), require("dapui")
  require("dap-go").setup({
    delve = {
      path = vim.fn.exepath("dlv") ~= "" and vim.fn.exepath("dlv") or "dlv",
    },
    dap_configurations = {
      {
        type = "go",
        name = "Debug current package",
        request = "launch",
        program = "${fileDirname}",
        cwd = "${fileDirname}",
      },
    },
  })
  dapui.setup({})
  dap.listeners.after.event_initialized.dotfiles = function() dapui.open() end
  dap.listeners.before.event_terminated.dotfiles = function() dapui.close() end
  dap.listeners.before.event_exited.dotfiles = function() dapui.close() end

  local test = require("neotest")
  test.setup({
    adapters = {
      require("neotest-go")({
        args = { "-count=1", "-timeout=60s" },
        recursive_run = true,
      }),
    },
  })

  -- Restore files, tabs and splits without restarting shell commands.
  vim.opt.sessionoptions = { "buffers", "curdir", "tabpages", "winsize", "help", "folds" }
  require("persistence").setup({})

  local function map(key, fn, desc)
    vim.keymap.set("n", key, fn, { desc = desc })
  end
  map("<leader>db", dap.toggle_breakpoint, "Toggle breakpoint")
  map("<leader>dB", function()
    vim.ui.input({ prompt = "Breakpoint condition: " }, function(condition)
      if condition and condition ~= "" then dap.set_breakpoint(condition) end
    end)
  end, "Conditional breakpoint")
  map("<leader>dc", function()
    if not dap.session() then vim.cmd.update() end
    dap.continue()
  end, "Start / continue debugging")
  map("<leader>dn", dap.step_over, "Step over")
  map("<leader>di", dap.step_into, "Step into")
  map("<leader>do", dap.step_out, "Step out")
  map("<leader>dq", dap.terminate, "Stop debugging")
  map("<leader>du", dapui.toggle, "Toggle debug panels")
  map("<leader>de", dapui.eval, "Evaluate expression")
  map("<leader>dt", function()
    vim.cmd.update()
    require("dap-go").debug_test()
  end, "Debug nearest Go test")
  map("<leader>Tn", function() vim.cmd.update(); test.run.run() end, "Run nearest test")
  map("<leader>Tf", function() vim.cmd.update(); test.run.run(vim.api.nvim_buf_get_name(0)) end, "Run test file")
  map("<leader>Tp", function() vim.cmd.update(); test.run.run(vim.fn.expand("%:p:h")) end, "Run package tests")
  map("<leader>Ta", function()
    local root = vim.fs.root(0, "go.mod")
    if not root then
      vim.notify("No go.mod found for this buffer", vim.log.levels.WARN)
      return
    end
    vim.cmd.update()
    test.run.run(root)
  end, "Run module tests")
  map("<leader>Tl", function() test.run.run_last() end, "Run last test")
  map("<leader>Ts", function() test.summary.toggle() end, "Toggle test summary")
  map("<leader>To", function() test.output.open({ enter = true }) end, "Test output")
  map("<leader>Tj", function() test.jump.next({ status = "failed" }) end, "Next failed test")
  map("<leader>Tk", function() test.jump.prev({ status = "failed" }) end, "Previous failed test")
  map("<leader>Tx", function() test.run.stop() end, "Stop tests")
  map("<leader>sr", function() require("persistence").load() end, "Restore project session")
  map("<leader>sl", function() require("persistence").load({ last = true }) end, "Restore last session")
  map("<leader>ss", function() require("persistence").select() end, "Select saved session")
  map("<leader>sd", function() require("persistence").stop() end, "Stop saving session")
end

return M
