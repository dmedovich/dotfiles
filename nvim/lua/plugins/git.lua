-- ╔══════════════════════════════════════╗
-- ║       honeynil — plugins/git         ║
-- ╚══════════════════════════════════════╝

return {
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      signs = {
        add          = { text = "▎" },
        change       = { text = "▎" },
        delete       = { text = "" },
        topdelete    = { text = "" },
        changedelete = { text = "▎" },
        untracked    = { text = "▎" },
      },
      signcolumn         = true,
      numhl              = false,
      linehl             = false,
      word_diff          = false,
      watch_gitdir       = { interval = 1000, follow_files = true },
      attach_to_untracked = true,
      current_line_blame = true,
      current_line_blame_opts = {
        virt_text         = true,
        virt_text_pos     = "eol",
        delay             = 800,
        ignore_whitespace = false,
      },
      current_line_blame_formatter = " 󰶻 <author>, <author_time:%Y-%m-%d> · <summary>",
      sign_priority = 6,
      update_debounce = 100,
      status_formatter = nil,
      max_file_length  = 40000,
      preview_config   = {
        border   = "rounded",
        style    = "minimal",
        relative = "cursor",
        row      = 0,
        col      = 1,
      },
      on_attach = function(bufnr)
        local gs = package.loaded.gitsigns
        local map = function(mode, l, r, opts)
          opts = opts or {}
          opts.buffer = bufnr
          vim.keymap.set(mode, l, r, opts)
        end

        map("n", "]h", function()
          if vim.wo.diff then return "]h" end
          vim.schedule(function() gs.next_hunk() end)
          return "<Ignore>"
        end, { expr = true, desc = "Git: Next hunk" })

        map("n", "[h", function()
          if vim.wo.diff then return "[h" end
          vim.schedule(function() gs.prev_hunk() end)
          return "<Ignore>"
        end, { expr = true, desc = "Git: Prev hunk" })

        map({ "n", "v" }, "<leader>hs", function()
          gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
        end, { desc = "Git: Stage hunk" })

        map({ "n", "v" }, "<leader>hr", function()
          gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
        end, { desc = "Git: Reset hunk" })

        map("n", "<leader>hS",  gs.stage_buffer,       { desc = "Git: Stage buffer" })
        map("n", "<leader>hu",  gs.undo_stage_hunk,    { desc = "Git: Undo stage hunk" })
        map("n", "<leader>hR",  gs.reset_buffer,       { desc = "Git: Reset buffer" })
        map("n", "<leader>hp",  gs.preview_hunk,       { desc = "Git: Preview hunk" })
        map("n", "<leader>hb",  function() gs.blame_line({ full = true }) end, { desc = "Git: Blame line" })
        map("n", "<leader>hd",  gs.diffthis,            { desc = "Git: Diff this" })
        map("n", "<leader>hD",  function() gs.diffthis("~") end, { desc = "Git: Diff this ~" })
        map("n", "<leader>htb", gs.toggle_current_line_blame, { desc = "Git: Toggle blame" })
        map("n", "<leader>htd", gs.toggle_deleted,      { desc = "Git: Toggle deleted" })

        map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", { desc = "Git: Select hunk" })
      end,
    },
  },

  {
    "kdheepak/lazygit.nvim",
    lazy = true,
    cmd  = { "LazyGit", "LazyGitConfig", "LazyGitCurrentFile", "LazyGitFilter", "LazyGitFilterCurrentFile" },
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>gg", "<cmd>LazyGit<cr>",               desc = "LazyGit" },
      { "<leader>gB", "<cmd>LazyGitCurrentFile<cr>",    desc = "LazyGit current file" },
      { "<leader>gF", "<cmd>LazyGitFilter<cr>",         desc = "LazyGit filter" },
      { "<leader>gL", "<cmd>LazyGitFilterCurrentFile<cr>", desc = "LazyGit log (file)" },
    },
    config = function()
      vim.g.lazygit_floating_window_winblend  = 0
      vim.g.lazygit_floating_window_scaling_factor = 0.9
      vim.g.lazygit_floating_window_border_chars = { "╭","─","╮","│","╯","─","╰","│" }
      vim.g.lazygit_use_neovim_remote          = 1
    end,
  },

  {
    "sindrets/diffview.nvim",
    cmd  = { "DiffviewOpen", "DiffviewClose", "DiffviewToggleFiles", "DiffviewFocusFiles", "DiffviewFileHistory" },
    keys = {
      { "<leader>gv", "<cmd>DiffviewOpen<cr>",               desc = "Diffview: Open" },
      { "<leader>gh", "<cmd>DiffviewFileHistory %<cr>",      desc = "Diffview: File history" },
      { "<leader>gH", "<cmd>DiffviewFileHistory<cr>",        desc = "Diffview: Repo history" },
      { "<leader>gq", "<cmd>DiffviewClose<cr>",              desc = "Diffview: Close" },
    },
    opts = {
      enhanced_diff_hl = true,
      view = {
        default = { layout = "diff2_horizontal" },
        merge_tool = {
          layout         = "diff3_horizontal",
          disable_diagnostics = true,
        },
      },
      file_panel = {
        listing_style = "tree",
        win_config    = { position = "left", width = 35 },
      },
    },
  },
}
