# toc.nvim

A fancy Table of Contents for Markdown, rendered in a fixed-width split on the
right. Inspired by [markview.nvim](https://github.com/OXY2DEV/markview.nvim):
per-level glyphs, tree guides, section numbering, and typed entries for tasks,
code blocks, callouts, tables, images and links. Moving the cursor in the TOC
moves the cursor in the source document (and vice-versa), with a beacon flash on
jump.

```
 󰠶 Table of Contents

󰼏 heading 1.1 Introduction
├╴󰼐 heading 2.1 Getting Started
│ ├╴ task 1 install the plugin
│ ╰╴ task 2 read the docs
├╴󰼐 heading 2.2 Usage
│ ├╴ code 1 lua
│ ╰╴ note 1 call setup once
╰╴󰼐 heading 2.3 Media
  ╰╴ image 1 architecture
```

## Features

- TOC split on the right (or left); fixed width or `"auto"` to fit content (+ padding)
- Cursor **follow** both ways: TOC ↔ source (`follow_cursor`, `follow_source`)
- **Beacon** flash on the jumped-to line (`effects.beacon`)
- Active-heading **sign + line highlight** in the TOC
- Four display **modes**: `full` / `glyph-only` / `text-only` / `minimal`
- **Heading numbering**: `level` (2.1), `nested` (1.1.1), `flat` (1, 2) or off
- **Typed elements**: headings, tasks, code, callouts, tables, images, links,
  bullets — each with its own glyph and an identity label (`code 1`, `anchor 1`);
  callouts label by type (`note 1`, `warning 1`); code blocks show their
  language, with a devicons icon when available (`code 1 [ lua]`)
- Recognises ATX, setext, and raw HTML (`<h1>`–`<h6>`) headings
- Root-level headings carry no tree connector; children nest under them
- Truncation (`…`) so long entries never overflow the panel
- Debounced live refresh on edit, always refresh on save, auto-rebind on buffer switch
- Auto-open on a Markdown buffer (`auto_enabled`); auto-close on a non-markdown file (`auto_close`)
- Colorscheme-aware highlights (links to markview groups when present)

## Install

[lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "toc.nvim",
  dir = "~/Dev/nvim-project/toc.nvim", -- local development path
  ft = { "markdown", "quarto", "rmd", "mdx" },
  dependencies = {
    "nvim-tree/nvim-web-devicons", -- optional: code-block language icons
    "OXY2DEV/markview.nvim",       -- optional: borrow heading/checkbox/callout glyphs & colours
  },
  keys = {
    { "<leader>t", "<cmd>Toc toggle<cr>", desc = "Toggle TOC" },
  },
  config = function()
    require("toc").setup {}
  end,
}
```

Parsing is regex-based, so all dependencies are **optional**:

- [nvim-web-devicons](https://github.com/nvim-tree/nvim-web-devicons) — coloured
  language icons in code-block labels (`code 1 [ lua]`). Without it you get `code 1 [lua]`.
- [markview.nvim](https://github.com/OXY2DEV/markview.nvim) — reuses its heading,
  checkbox and callout glyphs/colours (`markview = true`).

A [Nerd Font](https://www.nerdfonts.com) is needed for the glyphs (except the
`plain` preset, which is Nerd-Font-free).

## Usage

| Command | Description |
| --- | --- |
| `:Toc` / `:Toc toggle` | Toggle the TOC panel |
| `:Toc open` | Open |
| `:Toc close` | Close |
| `:Toc refresh` | Re-parse and re-render |

Default keymaps inside the TOC window:

| Key | Action |
| --- | --- |
| `<CR>` | Jump to the entry and focus the source window |
| `o` | Jump but keep focus in the TOC |
| `J` / `K` | Move to next / previous entry (syncs the source) |
| `R` | Refresh |
| `q` | Close |

Lua API: `require("toc").open() / close() / toggle() / refresh() / is_open()`.

## Configuration

Values passed to `setup()` are deep-merged over the defaults below.

```lua
require("toc").setup {
  width = 34,               -- fixed column count, or "auto" to fit the longest line
  padding = 2,              -- extra columns beside the content when width = "auto"
  width_max = 60,           -- upper bound for the auto width
  position = "right",       -- "right" | "left"
  follow_cursor = true,     -- TOC movement drives the source cursor
  follow_source = true,     -- source movement marks the active entry
  focus_on_open = true,     -- focus the TOC when it opens
  close_on_select = false,  -- close the TOC after <CR>
  auto_refresh = true,      -- live-update as the document changes
  refresh_debounce = 150,   -- ms of quiet before a live refresh (0 = instant; save is always instant)
  auto_enabled = true,      -- auto-open on a Markdown-family buffer
  auto_close = true,        -- auto-close when the window switches to a non-markdown file
  preset = nil,             -- a named preset (see Presets) or an inline table
  markview = true,          -- borrow heading/checkbox/callout glyphs from markview.nvim
  filetypes = { "markdown", "quarto", "rmd", "mdx" },
  indent = 2,               -- per-level indent when guides = false
  guides = true,            -- draw tree guide lines
  truncate = true,          -- clip overflowing text with "…"
  title = "󰠶 Table of Contents", -- false hides the header line

  -- Display mode:
  --   "full"       glyph + number/label + text
  --   "glyph-only" glyph + number/label (text hidden)
  --   "text-only"  number/label + text (glyph hidden)
  --   "minimal"    glyph only
  mode = "full",

  -- Heading numbering: "level" (2.1), "nested" (1.1.1), "flat" (1,2) or false.
  numbers = "level",
  -- Show label prefixes ("heading", "anchor", …); false = numbers/indices only.
  labels = true,

  -- One block per element kind: enable it, its glyph, and its label prefix.
  -- Headings use the per-level glyphs.heading array; other kinds use `glyph`.
  -- Tasks use done/todo; callouts label themselves by type (note 1, warning 1).
  elements = {
    heading = { enable = true,  label = "heading" },
    task    = { enable = true,  label = "task", done = "", todo = "" },
    code    = { enable = true,  label = "code",  glyph = "", lang_glyph = true }, -- "code 1 [ lua]"
    callout = { enable = true,  glyph = "" },
    table   = { enable = true,  label = "table", glyph = "" },
    image   = { enable = true,  label = "image", glyph = "" },
    link    = { enable = false, label = "anchor", glyph = "" },
    bullet  = { enable = false, label = "item",  glyph = "" },
  },

  -- Structural glyphs (heading icons + tree connectors).
  glyphs = {
    heading = { "󰼏", "󰼐", "󰼑", "󰼒", "󰼓", "󰼔" }, -- levels 1–6
    fallback = "󰗨",
    branch = "├╴", last = "╰╴", vertical = "│ ",
  },

  -- Movement feedback.
  effects = {
    beacon = { enable = true, hl = "TocBeacon", duration = 250, fade_steps = 8 },
    active_sign = { enable = true, text = "▎", hl = "TocActiveSign" },
    active_line = { enable = true, hl = "TocActiveLine" },
  },

  keymaps = {
    jump = "<CR>", jump_stay = "o", close = "q",
    refresh = "R", next = "J", prev = "K",
  },
}
```

## Presets

A preset is a named bundle of options. Pick one with `preset`, then override
anything you like on top — your explicit options always win.

```lua
require("toc").setup {
  preset = "compact",
  markview = true,
  elements = { link = { enable = true } }, -- overrides layered on top
}
```

| Preset | Look |
| --- | --- |
| `compact` | Narrow panel, glyph + label/number, no title |
| `boxed` | Roomy box-drawing tree (`├─ └─ │`), keeps glyphs & markview colours |
| `minimal` | Bare glyph tree — no numbers, labels, title or text |
| `writing` | Headings only, text-first, hierarchical numbers |
| `plain` | ASCII tree (`\|- ` `` `- `` `\| `), no Nerd Font / devicons |

`preset` also accepts an inline table (`preset = { width = 40, guides = false }`).

Layer order: **defaults → markview-derived → preset → your options**. So a
preset overrides markview glyphs, and your explicit `setup` keys override the
preset.

Register your own preset (e.g. in your config) and reference it by name:

```lua
require("toc.presets").notes = {
  mode = "text-only",
  numbers = "flat",
  title = "󰠷 Notes",
}
require("toc").setup { preset = "notes" }
```

## Highlight Groups

Defaults link to markview's palette when available and fall back to core /
treesitter groups otherwise. Override any of them with `nvim_set_hl`:

```lua
vim.api.nvim_set_hl(0, "TocHeading1", { fg = "#e06c75", bold = true })
```

| Group | Purpose |
| --- | --- |
| `TocHeading1`–`TocHeading6` | Per-level heading glyph |
| `TocText` | Heading/entry text (defaults to `Normal`) |
| `TocNumber` | Section numbers and element labels |
| `TocTitle` | Panel header |
| `TocGuide` | Tree guide lines |
| `TocTask` / `TocTaskDone` | Unchecked / checked task glyph |
| `TocCode` / `TocCallout` / `TocTable` / `TocImage` / `TocLink` / `TocBullet` | Element glyphs |
| `TocActiveSign` / `TocActiveLine` | Active-entry sign / line |
| `TocBeacon` | Jump beacon flash |

## Health & Help

- `:checkhealth toc` — Neovim version, `termguicolors`, loaded config, indexed elements.
- `:help toc.nvim` — full documentation (`doc/toc.txt`).

## Testing

```
nvim --headless -u tests/minimal_init.lua -c "luafile tests/toc_spec.lua"
```

The suite covers parsing (headings, typed elements, nested fences, HTML
headings), rendering, all display modes, numbering/labels, callout typing,
cursor follow both ways, `<CR>` jump, the beacon, debounced/save refresh,
buffer-switch rebinding, auto-open, and toggle/close.
