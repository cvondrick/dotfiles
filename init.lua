vim.loader.enable()

-- Use local disk for Neovim data to avoid NFS slowness (only on Columbia servers)
if vim.fn.isdirectory("/proj") == 1 then
  local local_dir = "/tmp/" .. os.getenv("USER") .. "-nvim"
  vim.fn.setenv("XDG_DATA_HOME", local_dir .. "/.local/share")
  vim.fn.setenv("XDG_STATE_HOME", local_dir .. "/.local/state")
  vim.fn.setenv("XDG_CACHE_HOME", local_dir .. "/.cache")
end

vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.g.have_nerd_font = true

vim.opt.number = true
--vim.opt.relativenumber = true

vim.opt.mouse = "a"

vim.opt.showmode = false
vim.opt.laststatus = 3

-- Clipboard
vim.schedule(function()
  vim.opt.clipboard = "unnamedplus"
end)
--vim.api.nvim_set_keymap('n', 'd', '"_d', { noremap = true })
--vim.api.nvim_set_keymap('v', 'd', '"_d', { noremap = true })
vim.api.nvim_set_keymap("n", "c", '"_c', { noremap = true })
vim.api.nvim_set_keymap("v", "c", '"_c', { noremap = true })
vim.api.nvim_set_keymap("n", "C", '"_C', { noremap = true })
vim.api.nvim_set_keymap("v", "C", '"_C', { noremap = true })

vim.opt.breakindent = true
vim.opt.undofile = true
vim.opt.ignorecase = true
vim.opt.smartcase = true

vim.opt.signcolumn = "yes"

vim.opt.updatetime = 250

vim.opt.splitright = true
vim.opt.splitbelow = true

vim.o.expandtab = true
vim.o.tabstop = 4
vim.o.shiftwidth = 4
vim.o.softtabstop = 4

vim.opt.list = true
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

-- Preview substitutions live, as you type!
vim.opt.inccommand = "split"

vim.opt.cursorline = true
vim.opt.scrolloff = 5

vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

vim.keymap.set("n", "<C-n>", ":bnext<CR>")
vim.keymap.set("n", "<C-p>", ":bprev<CR>")

-- treesitter fold
-- vim.wo.foldmethod = 'expr'
-- vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'

-- Navigation keymaps
--vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
--vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
--vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
--vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Highlight when yanking (copying) text",
  group = vim.api.nvim_create_augroup("kickstart-highlight-yank", { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

vim.api.nvim_create_autocmd("BufReadPost", {
  desc = "Open file at the last position it was edited earlier",
  group = misc_augroup,
  pattern = "*",
  command = 'silent! normal! g`"zv',
})

vim.api.nvim_create_augroup("MarkdownWrap", { clear = true })
vim.api.nvim_create_autocmd("FileType", {
  group = "MarkdownWrap",
  pattern = "markdown",
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
    vim.opt_local.breakat = " \\;,!?()"

    vim.api.nvim_buf_set_keymap(0, "n", "k", "gk", { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(0, "n", "j", "gj", { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(0, "n", "0", "g0", { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(0, "n", "$", "g$", { noremap = true, silent = true })
  end,
})

-- Lazy plugin manager
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    error("Error cloning lazy.nvim:\n" .. out)
  end
end ---@diagnostic disable-next-line: undefined-field
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  { "tpope/vim-sleuth" },

  { -- Adds git related signs to the gutter, as well as utilities for managing changes
    "lewis6991/gitsigns.nvim",
    opts = {},
  },

  {
    "folke/todo-comments.nvim",
    event = "VimEnter",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = { signs = false },
  },

  {
    "mason-org/mason.nvim",
    opts = {},
  },

  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "mason-org/mason.nvim" },
    opts = {
      ensure_installed = {
        "pyright",
        "ts_ls",
        "lua_ls",
        "bashls",
        "cssls",
        "html",
        "jsonls",
      },
      automatic_installation = true,
      automatic_enable = false,  -- Disable automatic setup to prevent duplicates
    },
  },

  {
    "neovim/nvim-lspconfig",
    dependencies = { "williamboman/mason-lspconfig.nvim" },
    config = function()
      local lspconfig = require("lspconfig")

      lspconfig.pyright.setup({})

      lspconfig.ts_ls.setup({})

      lspconfig.lua_ls.setup({
        on_init = function(client)
          local path = client.workspace_folders[1].name
          if vim.loop.fs_stat(path .. "/.luarc.json") or vim.loop.fs_stat(path .. "/.luarc.jsonc") then
            return
          end

          client.config.settings.Lua = vim.tbl_deep_extend("force", client.config.settings.Lua, {
            runtime = { version = "LuaJIT" },
            -- Make the server aware of Neovim runtime files
            workspace = {
              checkThirdParty = false,
              library = { vim.env.VIMRUNTIME },
            },
          })
        end,
        settings = { Lua = {} },
      })

      lspconfig.bashls.setup({})

      lspconfig.cssls.setup({})

      lspconfig.html.setup({})

      lspconfig.jsonls.setup({})

      vim.diagnostic.config({
        virtual_text = false,
        underline = true,
        update_in_insert = false,
        severity_sort = true,

        signs = {
          --severity = { min = vim.diagnostic.severity.WARN },
          text = {
            [vim.diagnostic.severity.ERROR] = "✘",
            [vim.diagnostic.severity.WARN] = "▲",
            [vim.diagnostic.severity.HINT] = "⚑",
            [vim.diagnostic.severity.INFO] = "»",
          },
        },
      })

      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("kickstart-lsp-attach", { clear = true }),
        callback = function(event)
          local map = function(keys, func, desc)
            vim.keymap.set("n", keys, func, { buffer = event.buf, desc = "LSP: " .. desc })
          end

          map("gd", function()
            Snacks.picker.lsp_definitions()
          end, "[G]oto [D]efinition")
          vim.keymap.set("n", "gr", function()
            Snacks.picker.lsp_references()
          end, { buffer = event.buf, desc = "LSP: [G]oto [R]eferences", nowait = true })
          map("K", vim.lsp.buf.hover, "Hover Documentation")
          map("ga", vim.lsp.buf.code_action, "Code [A]ction")
        end,
      })

      --vim.diagnostic.disable()
    end,
  },

  -- {
  --   "ray-x/lsp_signature.nvim",
  --   lazy = false,
  --   opts = {
  --     floating_window = false,
  --     hint_enable = true,
  --     hint_prefix = {
  --       above = "↙ ", -- when the hint is on the line above the current line
  --       current = "← ", -- when the hint is on the same line
  --       below = "↖ ", -- when the hint is on the line below the current line
  --     },
  --   },
  --   config = function(_, opts)
  --     require("lsp_signature").setup(opts)
  --   end,
  -- },

  {
    "rachartier/tiny-inline-diagnostic.nvim",
    event = "VeryLazy",
    lazy = true,
    opts = {},
  },

  { -- Collection of various small independent plugins/modules
    "echasnovski/mini.nvim",
    config = function()
      -- Examples:
      --  - va)  - [V]isually select [A]round [)]paren
      --  - vaf) - [V]isually select [A]round [F]unction
      --  - yinq - [Y]ank [I]nside [N]ext [Q]uote
      --  - ci'  - [C]hange [I]nside [']quote
      require("mini.ai").setup({ n_lines = 500 })

      -- - saiw) - [S]urround [A]dd [I]nner [W]ord [)]Paren
      -- - sd'   - [S]urround [D]elete [']quotes
      -- - sr)'  - [S]urround [R]eplace [)] [']
      --require('mini.surround').setup()

      --require('mini.pairs').setup()

      --require('mini.git').setup()

      require("mini.comment").setup()

      --require('mini.starter').setup()

      -- require('mini.completion').setup {
      --   delay = { completion = 1000, info = 100, signature = 100 },
      --   lsp_completion = { source_func = 'omnifunc' },
      --   window = { info = { border = 'rounded', height = 5 }, signature = { border = 'rounded', height = 5 } },
      -- }
    end,
  },

  {
    "windwp/nvim-ts-autotag",
    lazy = true,
    ft = { "html", "javascript", "typescript", "javascriptreact", "typescriptreact", "svelte", "vue", "tsx", "jsx", "xml", "php", "markdown", "astro", "glimmer", "handlebars", "hbs" },
    opts = {}
  },

  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = true,
    -- use opts = {} for passing setup options
    -- this is equalent to setup({}) function
  },

  -- {
  --   "HiPhish/rainbow-delimiters.nvim",
  --   event = "BufRead",
  --   config = function()
  --     --local colors = require("kanagawa.colors").setup()
  --     --local palette_colors = colors.palette
  --     --local theme_colors = colors.theme
  --
  --     --vim.cmd('highlight RainbowDelimiterRed guifg=' .. colors.palette.autumnRed)
  --     --vim.cmd('highlight RainbowDelimiterYellow guifg=' .. colors.palette.autumnYellow)
  --     --vim.cmd('highlight RainbowDelimiterBlue guifg=' .. colors.palette.lightBlue)
  --     --vim.cmd('highlight RainbowDelimiterOrange guifg=' .. colors.palette.springGreen)
  --     --vim.cmd('highlight RainbowDelimiterGreen guifg=' .. colors.palette.surimiOrange)
  --     --vim.cmd('highlight RainbowDelimiterViolet guifg=' .. colors.palette.oniViolet)
  --     --vim.cmd('highlight RainbowDelimiterViolet guifg=' .. colors.palette.springBlue)
  --
  --     local rainbow = require("rainbow-delimiters")
  --
  --     require("rainbow-delimiters.setup").setup({
  --       whitelist = { "html" },
  --       --strategy = { html = rainbow.strategy['local'] },
  --     })
  --   end,
  -- },

  { -- Highlight, edit, and navigate code
    "nvim-treesitter/nvim-treesitter",
    event = "BufReadPre",
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = {
          "bash",
          "c",
          "diff",
          "html",
          "lua",
          "luadoc",
          "markdown",
          "markdown_inline",
          "query",
          "vim",
          "vimdoc",
          "python",
          "javascript",
          "css",
          "regex",
        },
        -- Autoinstall languages that are not installed
        auto_install = true,
        highlight = {
          enable = true,
          -- Some languages depend on vim's regex highlighting system (such as Ruby) for indent rules.
          --  If you are experiencing weird indenting issues, add the language to
          --  the list of additional_vim_regex_highlighting and disabled languages for indent.
          additional_vim_regex_highlighting = { "ruby" },
        },
        indent = { enable = true, disable = { "ruby" } },

        incremental_selection = {
          enable = true,
          keymaps = {
            init_selection = false,
            node_incremental = "v",
            node_decremental = "V",
          },
        },

        textobjects = {
          select = {
            enable = true,
            keymaps = {
              ["af"] = "@function.outer",
              ["if"] = "@function.inner",
              ["ac"] = "@class.outer",
              ["ic"] = "@class.inner",
            },
          },

          swap = {
            enable = true,
            swap_next = {
              ["<leader>a"] = "@parameter.inner",
            },
            swap_previous = {
              ["<leader>A"] = "@parameter.inner",
            },
          },
        },
      })
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter-textobjects",
  },

  {
    "smjonas/inc-rename.nvim",
    opts = {},
    init = function()
      vim.keymap.set("n", "R", function()
        return ":IncRename " .. vim.fn.expand("<cword>")
      end, { expr = true })
    end,
  },

  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },

    opts = {
      options = {
        icons_enabled = true,
        --theme = 'gruvbox', -- also dracula, wombat are good
        --theme = 'vscode',
        --theme = 'kanagawa',
        theme = "auto",
        --theme = 'tokyonight',
        --component_separators = { left = '', right = ''},
        --section_separators = { left = '', right = ''},
        --component_separators = { left = "", right = "" },
        --section_separators = { left = "", right = "" },
        --always_divide_middle = false,
      },
      sections = {
        lualine_c = { { "filename", file_status = true, path = 1 } },
        lualine_x = { "filetype", "filesize" },
      },
      disabled_filetypes = {
        "aerial",
      },
      ignore_focus = { "aerial" },
      extensions = { "aerial" },
      tabline = {
        lualine_c = {
          {
            "buffers",
            max_length = vim.o.columns * 9 / 10,
            use_mode_colors = false,
            -- buffers_color = { 
            --   active = { fg = "Normal", bg = "Visual", gui = "bold" },
            --   inactive = { fg = "Comment" },
            -- },
            --buffers_color = {
            --  active = "CursorLineNr",
            --  --active = 'CursorLine',
            --  inactive = "CursorLineFold",
            --},
            -- buffers_color = {
            --   active = { bg = '#54546D', fg = '#DCD7BA' },
            --   inactive = { bg = '#2A2A37', fg = '#727169' },
            -- },
          },
        },
        lualine_y = {
          {
            "tabs",
            mode = 0,
            use_mode_colors = false,
            --tabs_color = {
            --  active = "CursorLineSign",
            --  inactive = "CursorLineFold",
            --},
          },
        },
        lualine_x = { { "aerial", depth = 2, sep = "  " } },
      },
    },
  },


  { -- Autoformat
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    keys = {
      {
        "<leader>j",
        function()
          require("conform").format({ async = true, lsp_fallback = true })
        end,
        mode = "",
        desc = "[F]ormat buffer",
      },
    },
    opts = {
      notify_on_error = true,
      --format_on_save = function(bufnr)
      --  -- Disable "format_on_save lsp_fallback" for languages that don't
      --  -- have a well standardized coding style. You can add additional
      --  -- languages here or re-enable it for the disabled ones.
      --  local disable_filetypes = { c = true, cpp = true }
      --  return {
      --    timeout_ms = 500,
      --    lsp_fallback = not disable_filetypes[vim.bo[bufnr].filetype],
      --  }
      --end,
      formatters_by_ft = {
        lua = { "stylua" },
        -- Conform can also run multiple formatters sequentially
        python = { "black", "isort" },
        javascript = { "prettier" },
        json = { "prettier" },
        css = { "prettier" },
        html = { "prettier" },
        markdown = { "prettier" },
        --
        -- You can use 'stop_after_first' to run the first available formatter from the list
        -- javascript = { "prettierd", "prettier", stop_after_first = true },
      },
      formatters = {
        stylua = {
          append_args = { "--indent-type", "Spaces", "--indent-width", "2" },
        },
        -- prettier = {
        --   prepend_args = {
        --     "--print-width",
        --     "100",
        --     "--bracket-same-line",
        --     "--html-whitespace-sensitivity",
        --     "ignore",
        --     "--prose-wrap",
        --     "always",
        --   },
        -- },
        isort = {
          append_args = { "--float-to-top", "--combine-as", "--balance", "--combine-star" },
        },
      },
    },
  },

  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    opts = {
      picker = {
        enabled = true,
      },
      explorer = {
        enabled = true,
      },
    },
    config = function(_, opts)
      require("snacks").setup(opts)
      -- Fix picker selection visibility
      vim.api.nvim_create_autocmd("ColorScheme", {
        pattern = "*",
        callback = function()
          -- Ensure directory paths are visible in selections
          vim.api.nvim_set_hl(0, "SnacksPickerDir", { link = "Directory" })
        end,
      })
      -- Set it immediately as well
      vim.api.nvim_set_hl(0, "SnacksPickerDir", { link = "Directory" })
    end,
    keys = {
      { "<C-f>", function() Snacks.picker.files() end, desc = "Find Files" },
      { "<C-g>", function() Snacks.picker.grep() end, desc = "Grep" },
      { "U", function() Snacks.picker.command_history() end, desc = "Command History" },
      { "<C-h>", function() Snacks.picker.buffers() end, desc = "Buffers" },
      { "<C-j>", function() Snacks.picker.treesitter() end, desc = "Treesitter Symbols" },
      { "<C-k>", function() Snacks.picker.colorschemes() end, desc = "Colorschemes" },
      { ",", function() Snacks.explorer() end, desc = "File Explorer" },
    },
  },

  {
    "github/copilot.vim",
    config = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "markdown",
        callback = function()
          vim.b.copilot_enabled = false
        end,
      })
    end,
  },

  {
    "stevearc/aerial.nvim",
    opts = {},
    lazy = true,
    keys = { { "<leader>,", "<cmd>AerialToggle<CR>", desc = "Toggle Aerial" } },
    cmd = { "AerialToggle", "AerialOpen", "AerialNavToggle" },
    -- Optional dependencies
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
    config = function()
      require("aerial").setup({
        -- optionally use on_attach to set keymaps when aerial has attached to a buffer
        on_attach = function(bufnr)
          -- Jump forwards/backwards with '{' and '}'
          vim.keymap.set("n", "{", "<cmd>AerialPrev<CR>", { buffer = bufnr })
          vim.keymap.set("n", "}", "<cmd>AerialNext<CR>", { buffer = bufnr })
        end,
      })

      vim.keymap.set("n", "<leader>,", "<cmd>AerialToggle<CR>")
      --vim.keymap.set("n", ".", "<cmd>AerialNavToggle<CR>")
    end,
  },

  {
    "chentoast/marks.nvim",
    config = function()
      require("marks").setup({})
    end,
  },

  {
    "chrisbra/Colorizer",
    init = function()
      vim.api.nvim_set_keymap("n", "<C-c>", ":ColorToggle<CR>", { noremap = true, silent = true })
    end,
  },

  {
    "KabbAmine/vCoolor.vim",
    init = function()
      vim.api.nvim_set_keymap("i", "<C-c>", "<Cmd>VCoolor<CR>", { noremap = true, silent = true })
    end,
  },


  -- THEMES
  {
    "rebelot/kanagawa.nvim",
    init = function()
      vim.cmd("colorscheme kanagawa")
    end,
    overrides = function(colors)
      local theme = colors.theme

      return {
        TelescopeTitle = { fg = theme.ui.special, bold = true },
        TelescopePromptNormal = { bg = theme.ui.bg_p1 },
        TelescopePromptBorder = { fg = theme.ui.bg_p1, bg = theme.ui.bg_p1 },
        TelescopeResultsNormal = { fg = theme.ui.fg_dim, bg = theme.ui.bg_m1 },
        TelescopeResultsBorder = { fg = theme.ui.bg_m1, bg = theme.ui.bg_m1 },
        TelescopePreviewNormal = { bg = theme.ui.bg_dim },
        TelescopePreviewBorder = { bg = theme.ui.bg_dim, fg = theme.ui.bg_dim },
        ["@variable.builtin"] = { italic = false },
      }
    end,
    opts = {
      theme = "wave",
      keywordStyle = { italic = false },
      statementStyle = { bold = false, italic = false },
      colors = {
        theme = {
          lotus = {
            ui = {
              bg_gutter = "none",
            },
          },
          wave = {
            ui = {
              bg_gutter = "none",
              --fg = '#DCD7BC',
              fg = "#c5c9c5",
              --fg = '#D9DBE2',
              bg_visual = "#54546D", --#2D4F67',

              -- DRAGON
              -- bg = '#181616',
              -- bg_p2 = '#393836',
              -- bg_gutter = '#282727',
              -- nontext = '#625e5a',
              -- fg = '#c5c9c5',
            },
          },
          dragon = {
            ui = {
              bg_gutter = "none",
            },
          },
        },
      },
    },
  },

  {
    "ribru17/bamboo.nvim",
    lazy = true,
    config = function()
      require("bamboo").setup({
        -- optional configuration here
      })
      require("bamboo").load()
    end,
  },

  {
    "webhooked/kanso.nvim",
    lazy = true,
  },

  {
    "sho-87/kanagawa-paper.nvim",
    lazy = true,
    opts = {},
  },

  {
    "folke/tokyonight.nvim",
    lazy = true,
    opts = {},
  },

  { "EdenEast/nightfox.nvim", lazy = true },

  { "catppuccin/nvim", name = "catppuccin", lazy = true },

  {
    "AstroNvim/astrotheme",
    lazy = true,
    opts = {},
  },

  {
    "Yazeed1s/minimal.nvim",
    lazy = True,
    init = function()
      vim.api.nvim_set_hl(0, "MatchParen", { bg = "#864709", bold = true })
    end,
  },

  {
    "sainnhe/gruvbox-material",
    lazy = true,
    config = function()
      -- Optionally configure and load the colorscheme
      -- directly inside the plugin declaration.
      vim.g.gruvbox_material_enable_italic = true
      vim.g.gruvbox_material_background = "hard"
    end,
  },

  { "ellisonleao/gruvbox.nvim", lazy = true, priority = 1000, config = true, opts = {} },

  {
    "sainnhe/sonokai",
    lazy = true,
    config = function()
      vim.g.sonokai_style = "default"
      vim.g.sonokai_enable_italic = true
    end,
  },

  { "projekt0n/github-nvim-theme", lazy = true },

  -- {
  --   "zenbones-theme/zenbones.nvim",
  --   -- Optionally install Lush. Allows for more configuration or extending the colorscheme
  --   -- If you don't want to install lush, make sure to set g:zenbones_compat = 1
  --   -- In Vim, compat mode is turned on as Lush only works in Neovim.
  --   dependencies = "rktjmp/lush.nvim",
  --   lazy = false,
  --   priority = 1000,
  --   -- you can set set configuration options here
  --   -- config = function()
  --   --     vim.g.zenbones_darken_comments = 45
  --   --     vim.cmd.colorscheme('zenbones')
  --   -- end
  -- },

  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      -- your configuration comes here
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
      delay = 1000,
    },
    keys = {
      {
        "<leader>?",
        function()
          require("which-key").show({ global = false })
        end,
        desc = "Buffer Local Keymaps (which-key)",
      },
    },
  },

  -- {
  --   'maxbrunsfeld/vim-yankstack',
  --   init = function()
  --     vim.g.yankstack_map_keys = 0 -- Set before the plugin loads
  --   end,
  --   config = function()
  --     vim.keymap.set('n', '<leader>p', '<Plug>yankstack_substitute_older_paste', { noremap = false, silent = true })
  --     vim.keymap.set('n', '<leader>P', '<Plug>yankstack_substitute_newer_paste', { noremap = false, silent = true })
  --   end,
  -- },

  -- {
  --   'ptdewey/yankbank-nvim',
  --   dependencies = 'kkharji/sqlite.lua',
  --   config = function()
  --     require('yankbank').setup {
  --       persist_type = 'sqlite',
  --     }
  --
  --     vim.keymap.set('n', '<leader>p', '<cmd>YankBank<CR>', { noremap = true })
  --   end,
  -- },
  --
  -- {
  --   'Aaronik/GPTModels.nvim',
  --   dependencies = {
  --     'MunifTanjim/nui.nvim',
  --     'nvim-telescope/telescope.nvim',
  --   },
  --   config = function()
  --     vim.api.nvim_set_keymap('v', '<leader>a', ':GPTModelsCode<CR>i', { noremap = true })
  --     vim.api.nvim_set_keymap('n', '<leader>a', ':GPTModelsCode<CR>i', { noremap = true })
  --
  --     vim.api.nvim_set_keymap('v', '<leader>c', ':GPTModelsChat<CR>', { noremap = true })
  --     vim.api.nvim_set_keymap('n', '<leader>c', ':GPTModelsChat<CR>', { noremap = true })
  --   end,
  -- },
  --
  --
  {
    "gbprod/yanky.nvim",
    opts = {
      highlight = {
        on_put = true,
        on_yank = false,
        timer = 500,
      },
    },
    init = function()
      vim.keymap.set({ "n", "x" }, "p", "<Plug>(YankyPutAfter)")
      vim.keymap.set({ "n", "x" }, "P", "<Plug>(YankyPutBefore)")
      vim.keymap.set({ "n", "x" }, "gp", "<Plug>(YankyGPutAfter)")
      vim.keymap.set({ "n", "x" }, "gP", "<Plug>(YankyGPutBefore)")
      -- vim.keymap.set("n", "]p", "<Plug>(YankyPreviousEntry)")
      -- vim.keymap.set("n", "[p", "<Plug>(YankyNextEntry)")
      vim.keymap.set("n", "<leader>p", function()
        Snacks.picker.registers()
      end)
    end,
  },

  -- {
  --   "yetone/avante.nvim",
  --   event = "VeryLazy",
  --   lazy = false,
  --   version = false, -- Set this to "*" to always pull the latest release version, or set it to false to update to the latest code changes.
  --   opts = {
  --     provider="openai",
  --     auto_suggestions_provider="copilot",
  --     windows = {
  --       position = "bottom",
  --       ask = {
  --         floating = false
  --       }
  --     }
  --     -- add any opts here
  --   },
  --   -- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
  --   build = "make",
  --   -- build = "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false" -- for windows
  --   dependencies = {
  --     "stevearc/dressing.nvim",
  --     "nvim-lua/plenary.nvim",
  --     "MunifTanjim/nui.nvim",
  --     --- The below dependencies are optional,
  --     "hrsh7th/nvim-cmp", -- autocompletion for avante commands and mentions
  --     "nvim-tree/nvim-web-devicons", -- or echasnovski/mini.icons
  --     "zbirenbaum/copilot.lua", -- for providers='copilot'
  --     {
  --       -- support for image pasting
  --       "HakonHarnes/img-clip.nvim",
  --       event = "VeryLazy",
  --       opts = {
  --         -- recommended settings
  --         default = {
  --           embed_image_as_base64 = false,
  --           prompt_for_file_name = false,
  --           drag_and_drop = {
  --             insert_mode = true,
  --           },
  --           -- required for Windows users
  --           use_absolute_path = true,
  --         },
  --       },
  --     },
  --     {
  --       -- Make sure to set this up properly if you have lazy=true
  --       "MeanderingProgrammer/render-markdown.nvim",
  --       opts = {
  --         file_types = { "markdown", "Avante" },
  --       },
  --       ft = { "markdown", "Avante" },
  --     },
  --   },
  -- },
}, {
  ui = { icons = {} },
  performance = {
    cache = {
      enabled = true,
    },
    reset_packpath = true,
    rtp = {
      reset = true,
      disabled_plugins = {
        "gzip",
        "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})

vim.api.nvim_create_user_command("ToggleKanagawa", function(opts)
  local current_theme = vim.g.colors_name
  --print(vim.inspect(require('kanagawa')))
  local k = require("kanagawa")
  if current_theme == "kanagawa" and k._CURRENT_THEME == "wave" then
    vim.cmd("colorscheme kanagawa-dragon")
    --k.load('dragon')
  else
    vim.cmd("colorscheme kanagawa-wave")
    --k.load('wave')
  end
end, {})

-- vim.api.nvim_create_user_command("ToggleKanagawa", function(opts)
--   -- List of themes to rotate through
--   local themes = { "dawnfox", "dayfox", "duskfox", "nightfox", "carbonfox" }
--
--   -- Helper function to find the index of an element in a table
--   local function find_index(tbl, value)
--     for i, v in ipairs(tbl) do
--       if v == value then
--         return i
--       end
--     end
--     return nil
--   end
--
--   -- Get the current theme and its index in the list
--   local current_theme = vim.g.colors_name
--   local current_index = find_index(themes, current_theme) or 0
--
--   -- Calculate the next theme index
--   local next_index = (current_index % #themes) + 1
--
--   -- Set the next theme
--   vim.cmd("colorscheme " .. themes[next_index])
-- end, {})

vim.api.nvim_set_keymap("n", "<leader>k", ":ToggleKanagawa<CR>", { noremap = true, silent = true })

local py2tmux = require("myplugins/py2tmux")

-- Bind py2tmux <leader><leader>
vim.api.nvim_set_keymap("n", "<leader><leader>", ":Py2Tmux<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("v", "<leader><leader>", ":Py2Tmux<CR>", { noremap = true, silent = true })

--local chat = require("myplugins/chat")

--vim.api.nvim_set_keymap("n", "\\", ":CodeCompanion<CR>", { noremap = true, silent = true })
--vim.api.nvim_set_keymap("n", "<c-\\>", ":AvanteToggle<CR>", { noremap = true, silent = true })
--vim.api.nvim_set_keymap("i", "<c-\\>", "<Esc>:AvanteToggle<CR>", { noremap = true, silent = true })
