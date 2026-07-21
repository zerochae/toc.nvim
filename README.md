# toc.nvim

A fancy table of contents for Markdown in a side split. Moving the cursor in
the TOC moves it in the document (and back), with a beacon flash on jump.

## Demo

<img width="1895" height="2000" alt="boxed" src="https://github.com/user-attachments/assets/3f53101d-e57c-475e-a1db-bddecb9eada0" />
<img width="1895" height="2000" alt="compact" src="https://github.com/user-attachments/assets/5d9d566e-515c-4dc4-b0e6-9c79f67ee7dc" />
<img width="1895" height="2000" alt="minimal" src="https://github.com/user-attachments/assets/51dee4cc-6af1-4d79-9d5d-c220bf68a3fd" />
<img width="1895" height="2000" alt="plain" src="https://github.com/user-attachments/assets/d73dfb40-faa8-464a-8ca5-578979319dbe" />
<img width="1895" height="2000" alt="writing" src="https://github.com/user-attachments/assets/ea130369-b4e7-42c9-897a-524f062ad7d1" />


## Features

- Two-way cursor follow with a jump beacon
- Typed entries: headings, tasks, code, callouts, tables, images, links, bullets, HTML disclosures and definition terms
- Display modes (`full` / `glyph-only` / `text-only` / `minimal`) and presets
- `level` / `nested` / `flat` numbering, per-element glyphs and labels
- Fixed or `auto` width, auto-open/close, debounced + on-save refresh
- Optional [markview.nvim](https://github.com/OXY2DEV/markview.nvim) glyphs/colours
- Optional [devicons](https://github.com/nvim-tree/nvim-web-devicons) language icons
- Optional [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) for full HTML file parsing
- Markdown, Vim help (`doc/*.txt`), and HTML out of the box; add formats under `lua/toc/parsers/`

## Install

[lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "zerochae/toc.nvim",
  ft = { "markdown", "quarto", "rmd", "mdx", "help", "html" },
  dependencies = { -- all optional
    "nvim-tree/nvim-web-devicons",
    "OXY2DEV/markview.nvim",
    "nvim-treesitter/nvim-treesitter", -- full HTML parsing (tables, disclosures)
  },
  keys = { { "<leader>t", "<cmd>Toc toggle<cr>", desc = "Toggle TOC" } },
  opts = {},
}
```

A [Nerd Font](https://www.nerdfonts.com) is needed for the glyphs (except the
`plain` preset).

Markdown and Vim help parse with no dependencies. HTML files use treesitter
when its parser is installed (`:TSInstall html`) and fall back to a limited
regex scanner otherwise, so tables and disclosures may be skipped without it.

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
