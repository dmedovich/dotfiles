-- ╔═══════════════════════════════════════╗
-- ║       honeynil — plugins/ui           ║
-- ╚═══════════════════════════════════════╝

local M = {}

M[1] = {
  "honeynil/colorscheme",
  name    = "honeynil-colorscheme",
  dir     = vim.fn.stdpath("config"),
  lazy    = false,
  priority = 1000,
  config  = function()
    vim.cmd.colorscheme("honeynil")
  end,
}

M[2] = {
  "folke/snacks.nvim",
  opts = {
    dashboard = {
      preset = {
        header = table.concat({
          "                                                     ",
          "  ██╗  ██╗ ██████╗ ███╗   ██╗███████╗██╗   ██╗     ",
          "  ██║  ██║██╔═══██╗████╗  ██║██╔════╝╚██╗ ██╔╝     ",
          "  ███████║██║   ██║██╔██╗ ██║█████╗   ╚████╔╝      ",
          "  ██╔══██║██║   ██║██║╚██╗██║██╔══╝    ╚██╔╝       ",
          "  ██║  ██║╚██████╔╝██║ ╚████║███████╗   ██║        ",
          "  ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚══════╝   ╚═╝        ",
          "               ██╗   ██╗██╗███╗   ███╗             ",
          "               ██║   ██║██║████╗ ████║             ",
          "               ██║   ██║██║██╔████╔██║             ",
          "               ╚██╗ ██╔╝██║██║╚██╔╝██║             ",
          "                ╚████╔╝ ██║██║     ██║              ",
          "                 ╚██╔╝  ╚═╝╚═╝     ╚═╝              ",
          "                                                     ",
        }, "\n"),
        keys = {
          { icon = "󰱼 ", key = "f", desc = "Find File",      action = "<cmd>Telescope find_files<cr>" },
          { icon = "󰺮 ", key = "g", desc = "Live Grep",      action = "<cmd>Telescope live_grep<cr>" },
          { icon = " ", key = "r", desc = "Recent Files",   action = "<cmd>Telescope oldfiles<cr>" },
          { icon = " ", key = "n", desc = "New File",       action = "<cmd>ene | startinsert<cr>" },
          { icon = "󰙅 ", key = "e", desc = "Explorer",       action = "<cmd>Neotree reveal toggle left<cr>" },
          { icon = " ", key = "G", desc = "LazyGit",        action = "<cmd>LazyGit<cr>" },
          { icon = "󰒲 ", key = "L", desc = "Lazy",            action = "<cmd>Lazy<cr>" },
          { icon = "󰥔 ", key = "M", desc = "Mason",           action = "<cmd>Mason<cr>" },
          { icon = " ", key = "q", desc = "Quit",           action = "<cmd>qa<cr>" },
        },
      },
      sections = {
        { section = "header" },
        { section = "keys",   gap = 1, padding = 1 },
        { section = "terminal", cmd = "go version 2>/dev/null | awk '{print \"  \" $3}' || echo ''", height = 1, padding = 1 },
        { icon = "󰄉 ", title = " Workspace", section = "terminal", cmd = "pwd | sed 's|^" .. vim.fn.expand("~") .. "|~|'", height = 1, padding = 0 },
        { section = "startup" },
      },
    },
  },
}

M[3] = {
  "nvim-lualine/lualine.nvim",
  event = "VeryLazy",
  opts = function()
    local honey = {
      normal = {
        a = { fg = "#1A1D23", bg = "#E09832", gui = "bold" },
        b = { fg = "#D8DEE9", bg = "#3B4252" },
        c = { fg = "#9099A5", bg = "#2E3440" },
      },
      insert  = { a = { fg = "#1A1D23", bg = "#A3BE8C", gui = "bold" } },
      visual  = { a = { fg = "#1A1D23", bg = "#B48EAD", gui = "bold" } },
      replace = { a = { fg = "#1A1D23", bg = "#BF616A", gui = "bold" } },
      command = { a = { fg = "#1A1D23", bg = "#8FBCBB", gui = "bold" } },
      terminal= { a = { fg = "#1A1D23", bg = "#81A1C1", gui = "bold" } },
      inactive = {
        a = { fg = "#9099A5", bg = "#2E3440" },
        b = { fg = "#9099A5", bg = "#2E3440" },
        c = { fg = "#9099A5", bg = "#2E3440" },
      },
    }

    return {
      options = {
        theme           = honey,
        globalstatus    = true,
        component_separators = { left = "", right = "" },
        section_separators  = { left = "", right = "" },
        disabled_filetypes  = { statusline = { "alpha", "snacks_dashboard" } },
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch", "diff", "diagnostics" },
        lualine_c = {
          { "filename", path = 1, symbols = { modified = " ●", readonly = " ", unnamed = " [No Name]" } },
        },
        lualine_x = {
          {
            function()
              local clients = vim.lsp.get_clients({ bufnr = 0 })
              if #clients == 0 then return "" end
              return " " .. clients[1].name
            end,
            color = { fg = "#E09832" },
          },
          "filetype",
          "encoding",
        },
        lualine_y = { "progress" },
        lualine_z = { "location" },
      },
    }
  end,
}

M[4] = {
  "akinsho/bufferline.nvim",
  event = "VeryLazy",
  opts = {
    options = {
      mode              = "buffers",
      separator_style   = "slant",
      always_show_bufferline = false,
      show_buffer_close_icons = true,
      show_close_icon         = false,
      color_icons             = true,
      diagnostics             = "nvim_lsp",
      diagnostics_indicator   = function(count, level)
        local icon = level:match("error") and " " or " "
        return " " .. icon .. count
      end,
      offsets = {
        { filetype = "neo-tree", text = "  honeynil", text_align = "center", separator = true },
      },
    },
  },
}

return M
