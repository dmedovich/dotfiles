return {
  {
    "nvim-telescope/telescope.nvim",
    cmd  = "Telescope",
    dependencies = {
      "nvim-lua/plenary.nvim",
      {
        "nvim-telescope/telescope-fzf-native.nvim",
        build = "make",
        cond  = function() return vim.fn.executable("make") == 1 end,
      },
      "nvim-telescope/telescope-ui-select.nvim",
    },
    opts = function()
      local actions = require("telescope.actions")
      local find_command

      if vim.fn.executable("fd") == 1 then
        find_command = { "fd", "--type", "f", "--strip-cwd-prefix", "--hidden", "--exclude", ".git" }
      else
        find_command = { "rg", "--files", "--hidden", "--glob", "!**/.git/*" }
      end

      return {
        defaults = {
          prompt_prefix   = "> ",
          selection_caret = "> ",
          entry_prefix    = "  ",
          multi_icon      = "+ ",
          path_display    = { "truncate" },
          sorting_strategy = "ascending",
          layout_strategy = "horizontal",
          selection_strategy = "reset",
          dynamic_preview_title = true,
          layout_config = {
            horizontal = {
              prompt_position = "top",
              preview_width   = 0.58,
              results_width   = 0.82,
            },
            vertical = {
              mirror = false,
            },
            width          = 0.90,
            height         = 0.84,
            preview_cutoff = 110,
          },
          border      = true,
          borderchars = {
            prompt  = { "-", "|", " ", "|", "+", "+", "|", "|" },
            results = { "-", "|", "-", "|", "+", "+", "+", "+" },
            preview = { "-", "|", "-", "|", "+", "+", "+", "+" },
          },
          mappings = {
            i = {
              ["<C-j>"]    = actions.move_selection_next,
              ["<C-k>"]    = actions.move_selection_previous,
              ["<C-n>"]    = actions.cycle_history_next,
              ["<C-p>"]    = actions.cycle_history_prev,
              ["<Esc>"]    = actions.close,
              ["<CR>"]     = actions.select_default,
              ["<C-v>"]    = actions.select_vertical,
              ["<C-s>"]    = actions.select_horizontal,
              ["<C-t>"]    = actions.select_tab,
              ["<C-u>"]    = actions.preview_scrolling_up,
              ["<C-d>"]    = actions.preview_scrolling_down,
              ["<C-q>"]    = actions.send_to_qflist + actions.open_qflist,
              ["<Tab>"]    = actions.toggle_selection + actions.move_selection_worse,
              ["<S-Tab>"]  = actions.toggle_selection + actions.move_selection_better,
            },
            n = {
              ["q"]    = actions.close,
              ["<Esc>"]= actions.close,
            },
          },
          vimgrep_arguments = {
            "rg", "--color=never", "--no-heading", "--with-filename",
            "--line-number", "--column", "--smart-case", "--hidden",
            "--glob", "!**/.git/*",
          },
          file_ignore_patterns = {
            "%.git/", "node_modules/", "vendor/", "%.cache/",
            "%.DS_Store", "%.jpg$", "%.jpeg$", "%.png$", "%.gif$",
          },
        },

        pickers = {
          find_files = {
            hidden      = true,
            find_command = find_command,
            preview_title = "File Preview",
          },
          live_grep  = {
            additional_args = { "--hidden" },
            preview_title = "Grep Preview",
          },
          buffers = {
            show_all_buffers = true,
            sort_lastused    = true,
            preview_title    = "Buffer Preview",
            mappings = {
              i = { ["<C-d>"] = actions.delete_buffer },
            },
          },
          lsp_references = {
            show_line  = false,
            include_declaration = false,
          },
        },

        extensions = {
          fzf = {
            fuzzy                   = true,
            override_generic_sorter = true,
            override_file_sorter    = true,
            case_mode               = "smart_case",
          },
          ["ui-select"] = {
            require("telescope.themes").get_dropdown({ previewer = false }),
          },
        },
      }
    end,
    config = function(_, opts)
      local telescope = require("telescope")
      telescope.setup(opts)
      pcall(telescope.load_extension, "fzf")
      pcall(telescope.load_extension, "ui-select")
    end,
  },
}
