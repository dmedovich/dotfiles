if vim.fn.has("nvim-0.12") == 0 or vim.pack == nil then
  error("This config requires Neovim 0.12+ with vim.pack")
end

vim.pack.add({
  { src = "https://github.com/nvim-lualine/lualine.nvim" },
  { src = "https://github.com/mason-org/mason.nvim" },
  { src = "https://github.com/mason-org/mason-lspconfig.nvim" },
  { src = "https://github.com/neovim/nvim-lspconfig" },
  { src = "https://github.com/nvim-neo-tree/neo-tree.nvim", version = "v3.x" },
  { src = "https://github.com/nvim-lua/plenary.nvim" },
  { src = "https://github.com/MunifTanjim/nui.nvim" },
  { src = "https://github.com/nvim-tree/nvim-web-devicons" },
  { src = "https://github.com/nvim-treesitter/nvim-treesitter" },
  { src = "https://github.com/Saghen/blink.cmp", version = vim.version.range("1.*") },
  { src = "https://github.com/rafamadriz/friendly-snippets" },
  { src = "https://github.com/ibhagwan/fzf-lua" },
  { src = "https://github.com/folke/which-key.nvim" },
  { src = "https://github.com/lewis6991/gitsigns.nvim" },
  { src = "https://github.com/stevearc/conform.nvim" },
  { src = "https://github.com/numToStr/Comment.nvim" },
  { src = "https://github.com/windwp/nvim-autopairs" },
  { src = "https://github.com/mfussenegger/nvim-lint" },
  { src = "https://github.com/lukas-reineke/indent-blankline.nvim" },
  { src = "https://github.com/folke/todo-comments.nvim" },
  { src = "https://github.com/sindrets/diffview.nvim" },
  { src = "https://github.com/NeogitOrg/neogit" },
}, {
  confirm = false,
  load = true,
})

local function setup(module, callback)
  local ok, plugin = pcall(require, module)
  if ok then
    callback(plugin)
  end
end

setup("lualine", function(lualine)
  lualine.setup({
    options = {
      component_separators = "",
      globalstatus = true,
      section_separators = "",
      theme = "auto",
    },
  })
end)

setup("which-key", function(which_key)
  which_key.setup({})
  which_key.add({
    { "<leader>f", group = "find" },
    { "<leader>g", group = "git" },
    { "<leader>h", group = "git hunks" },
    { "<leader>l", group = "lsp" },
  })
end)

setup("gitsigns", function(gitsigns)
  gitsigns.setup({
    current_line_blame = false,
    on_attach = function(bufnr)
      local gs = package.loaded.gitsigns
      local map = function(mode, lhs, rhs, desc, opts)
        opts = opts or {}
        opts.buffer = bufnr
        opts.desc = desc
        vim.keymap.set(mode, lhs, rhs, opts)
      end

      map("n", "]c", function()
        if vim.wo.diff then
          return "]c"
        end
        vim.schedule(gs.next_hunk)
        return "<Ignore>"
      end, "Next git hunk", { expr = true })

      map("n", "[c", function()
        if vim.wo.diff then
          return "[c"
        end
        vim.schedule(gs.prev_hunk)
        return "<Ignore>"
      end, "Previous git hunk", { expr = true })

      map("n", "<leader>hs", gs.stage_hunk, "Stage hunk")
      map("n", "<leader>hr", gs.reset_hunk, "Reset hunk")
      map("v", "<leader>hs", function()
        gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
      end, "Stage selected hunk")
      map("v", "<leader>hr", function()
        gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
      end, "Reset selected hunk")
      map("n", "<leader>hS", gs.stage_buffer, "Stage buffer")
      map("n", "<leader>hR", gs.reset_buffer, "Reset buffer")
      map("n", "<leader>hp", gs.preview_hunk, "Preview hunk")
      map("n", "<leader>hb", function()
        gs.blame_line({ full = true })
      end, "Blame line")
      map("n", "<leader>hd", gs.diffthis, "Diff this")
      map("n", "<leader>hD", function()
        gs.diffthis("~")
      end, "Diff this against previous")
    end,
  })
end)

setup("conform", function(conform)
  conform.setup({
    formatters_by_ft = {
      go = { "gofumpt", "gofmt" },
    },
    format_on_save = function(bufnr)
      if vim.bo[bufnr].filetype == "go" then
        return {
          lsp_format = "fallback",
          timeout_ms = 3000,
        }
      end
    end,
  })
end)

setup("Comment", function(comment)
  comment.setup({})
end)

setup("nvim-autopairs", function(autopairs)
  autopairs.setup({
    check_ts = true,
    disable_filetype = { "TelescopePrompt", "vim" },
  })
end)

setup("lint", function(lint)
  lint.linters_by_ft = {
    go = { "golangcilint" },
  }

  local group = vim.api.nvim_create_augroup("user_lint", { clear = true })
  vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost", "InsertLeave" }, {
    group = group,
    callback = function()
      lint.try_lint()
    end,
  })
end)

setup("ibl", function(ibl)
  ibl.setup({
    exclude = {
      buftypes = { "terminal", "nofile" },
      filetypes = {
        "neo-tree",
        "help",
        "man",
        "gitcommit",
        "NeogitStatus",
      },
    },
    indent = {
      char = "│",
    },
    scope = {
      enabled = true,
    },
  })
end)

setup("todo-comments", function(todo)
  todo.setup({
    signs = true,
    search = {
      command = "rg",
    },
  })
end)

setup("diffview", function(diffview)
  diffview.setup({})
end)

setup("neogit", function(neogit)
  neogit.setup({
    integrations = {
      diffview = true,
    },
  })
end)

setup("neo-tree", function(neo_tree)
  neo_tree.setup({
    close_if_last_window = true,
    filesystem = {
      bind_to_cwd = true,
      follow_current_file = {
        enabled = true,
      },
      filtered_items = {
        hide_dotfiles = false,
        hide_gitignored = true,
      },
      use_libuv_file_watcher = true,
    },
    popup_border_style = "rounded",
    window = {
      width = 32,
    },
  })
end)

setup("fzf-lua", function(fzf)
  fzf.setup({
    "fzf-native",
    fzf_opts = {
      ["--info"] = "inline",
      ["--layout"] = "reverse",
    },
    winopts = {
      height = 0.85,
      preview = {
        layout = "flex",
      },
      width = 0.85,
    },
  })
end)

setup("blink.cmp", function(blink)
  blink.setup({
    appearance = {
      nerd_font_variant = "mono",
    },
    completion = {
      documentation = {
        auto_show = false,
      },
    },
    fuzzy = {
      implementation = "prefer_rust_with_warning",
    },
    keymap = {
      preset = "enter",
    },
    sources = {
      default = { "lsp", "path", "snippets", "buffer" },
    },
  })
end)

setup("nvim-treesitter", function(treesitter)
  treesitter.setup({
    install_dir = vim.fn.stdpath("data") .. "/site",
  })

  treesitter.install({
    "go",
    "gomod",
    "gosum",
    "gowork",
    "lua",
    "luadoc",
    "query",
    "vim",
    "vimdoc",
    "zig",
  })
end)
