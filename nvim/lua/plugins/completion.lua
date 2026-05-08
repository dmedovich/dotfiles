-- ╔════════════════════════════════════════╗
-- ║     honeynil — plugins/completion      ║
-- ╚════════════════════════════════════════╝

return {
  {
    "garymjr/nvim-snippets",
    enabled = false,
  },
  {
    "hrsh7th/nvim-cmp",
    event        = "InsertEnter",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-cmdline",
      "saadparwaiz1/cmp_luasnip",
      "onsails/lspkind.nvim",
      {
        "L3MON4D3/LuaSnip",
        build = "make install_jsregexp",
        dependencies = { "rafamadriz/friendly-snippets" },
        config = function()
          require("luasnip.loaders.from_vscode").lazy_load()
          require("luasnip.loaders.from_vscode").lazy_load({
            paths = { vim.fn.stdpath("config") .. "/snippets" },
          })
        end,
      },
    },
    config = function()
      local cmp     = require("cmp")
      local luasnip = require("luasnip")
      local lspkind = require("lspkind")

      cmp.setup({
        snippet = {
          expand = function(args) luasnip.lsp_expand(args.body) end,
        },
        completion = {
          completeopt = "menu,menuone,noinsert",
        },
        window = {
          completion = {
            border   = "rounded",
            winhighlight = "Normal:CmpPmenu,CursorLine:PmenuSel,Search:None",
            scrollbar = false,
          },
          documentation = {
            border   = "rounded",
            winhighlight = "Normal:CmpDoc",
          },
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-n>"]    = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Insert }),
          ["<C-p>"]    = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Insert }),
          ["<C-b>"]    = cmp.mapping.scroll_docs(-4),
          ["<C-f>"]    = cmp.mapping.scroll_docs(4),
          ["<C-Space>"]= cmp.mapping.complete(),
          ["<C-e>"]    = cmp.mapping.abort(),
          ["<CR>"]     = cmp.mapping.confirm({ select = true }),
          ["<Tab>"]    = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.locally_jumpable(1) then
              luasnip.jump(1)
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"]  = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.locally_jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp", priority = 1000 },
          { name = "luasnip",  priority = 750 },
          { name = "path",     priority = 500 },
        }, {
          { name = "buffer",   priority = 250, keyword_length = 3 },
        }),
        formatting = {
          expandable_indicator = true,
          fields   = { "kind", "abbr", "menu" },
          format   = lspkind.cmp_format({
            mode           = "symbol_text",
            maxwidth       = 50,
            ellipsis_char  = "…",
            symbol_map = {
              Text          = "󰉿",
              Method        = "󰆧",
              Function      = "󰊕",
              Constructor   = "",
              Field         = "󰜢",
              Variable      = "󰀫",
              Class         = "󰠱",
              Interface     = "",
              Module        = "",
              Property      = "󰜢",
              Unit          = "󰑭",
              Value         = "󰎠",
              Enum          = "",
              Keyword       = "󰌋",
              Snippet       = "",
              Color         = "󰏘",
              File          = "󰈙",
              Reference     = "󰈇",
              Folder        = "󰉋",
              EnumMember    = "",
              Constant      = "󰏿",
              Struct        = "󰙅",
              Event         = "",
              Operator      = "󰆕",
              TypeParameter = "",
            },
            before = function(entry, vim_item)
              vim_item.menu = ({
                nvim_lsp = "[LSP]",
                luasnip  = "[Snip]",
                buffer   = "[Buf]",
                path     = "[Path]",
              })[entry.source.name]
              return vim_item
            end,
          }),
        },
        sorting = {
          comparators = {
            cmp.config.compare.offset,
            cmp.config.compare.exact,
            cmp.config.compare.score,
            function(entry1, entry2)
              local _, entry1_under = entry1.completion_item.label:find("^_+")
              local _, entry2_under = entry2.completion_item.label:find("^_+")
              entry1_under = entry1_under or 0
              entry2_under = entry2_under or 0
              if entry1_under > entry2_under then return false
              elseif entry1_under < entry2_under then return true end
            end,
            cmp.config.compare.kind,
            cmp.config.compare.sort_text,
            cmp.config.compare.length,
            cmp.config.compare.order,
          },
        },
        experimental = { ghost_text = { hl_group = "Comment" } },
      })

      cmp.setup.cmdline({ "/", "?" }, {
        mapping = cmp.mapping.preset.cmdline(),
        sources = { { name = "buffer" } },
      })

      cmp.setup.cmdline(":", {
        mapping = cmp.mapping.preset.cmdline(),
        sources = cmp.config.sources(
          { { name = "path" } },
          { { name = "cmdline", option = { ignore_cmds = { "Man", "!" } } } }
        ),
      })
    end,
  },
}
