# toc.nvim

A fancy table of contents for Markdown in a side split. Moving the cursor in
the TOC moves it in the document (and back), with a beacon flash on jump.

```
󰼏 heading 1.1 Introduction
├╴󰼐 heading 2.1 Getting Started
│ ├╴ task 1 install the plugin
│ ╰╴ task 2 read the docs
├╴󰼐 heading 2.2 Usage
│ ├╴ code 1 [ lua]
│ ╰╴ note 1 call setup once
╰╴󰼐 heading 2.3 Media
  ╰╴ image 1 architecture
```

## Features

- Two-way cursor follow with a jump beacon
- Typed entries: headings, tasks, code, callouts, tables, images, links, bullets
- Display modes (`full` / `glyph-only` / `text-only` / `minimal`) and presets
- `level` / `nested` / `flat` numbering, per-element glyphs and labels
- Fixed or `auto` width, auto-open/close, debounced + on-save refresh
- Optional [markview.nvim](https://github.com/OXY2DEV/markview.nvim) glyphs/colours
  and [devicons](https://github.com/nvim-tree/nvim-web-devicons) language icons

## Install

[lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "zerochae/toc.nvim",
  ft = { "markdown", "quarto", "rmd", "mdx" },
  dependencies = { -- both optional
    "nvim-tree/nvim-web-devicons",
    "OXY2DEV/markview.nvim",
  },
  keys = { { "<leader>t", "<cmd>Toc toggle<cr>", desc = "Toggle TOC" } },
  opts = {},
}
```

A [Nerd Font](https://www.nerdfonts.com) is needed for the glyphs (except the
`plain` preset).

## Usage

`:Toc [toggle|open|close|refresh]` (default: `toggle`). Inside the panel:
`<CR>` jump + focus, `o` jump + stay, `J`/`K` next/prev, `R` refresh, `q` close.

## Configuration

Everything is optional; call `require("toc").setup { ... }`. A quick start with
a preset:

```lua
require("toc").setup {
  preset = "compact",         -- compact | boxed | minimal | writing | plain
  width = "auto",             -- or a fixed column count
  numbers = "level",          -- level | nested | flat | false
  labels = true,              -- false = numbers/indices only
}
```

See the [preset gallery](./examples/) for rendered output, and `:help toc.nvim`
for the full option list, highlight groups, and defaults.
