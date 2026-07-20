-- Named configuration bundles applied via `setup { preset = "<name>" }`.
-- Each is a partial config layered over the defaults (and markview) but under
-- the user's explicit options. Register your own with:
--   require("toc.presets").mystyle = { ... }

local M = {}

-- Narrow glyph tree with labels/numbers, no title.
M.compact = {
  width = 26,
  title = false,
  mode = "glyph-only",
}

-- Bare glyph tree: icons only, no numbers, labels or title.
M.minimal = {
  title = false,
  mode = "minimal",
  numbers = false,
}

-- Prose outline: headings only, text-first, hierarchical numbers, no tree lines.
M.writing = {
  mode = "text-only",
  numbers = "nested",
  guides = false,
  elements = {
    task = { enable = false },
    code = { enable = false },
    callout = { enable = false },
    table = { enable = false },
    image = { enable = false },
    link = { enable = false },
    bullet = { enable = false },
  },
}

-- Roomy box-drawing tree, but keeps the Nerd Font glyphs and markview colours.
M.boxed = {
  glyphs = {
    branch = "├─ ",
    last = "└─ ",
    vertical = "│  ",
  },
}

-- No Nerd Font or devicons; box-drawing tree (standard Unicode, not PUA).
M.plain = {
  markview = false,
  glyphs = {
    heading = { "#", "##", "###", "####", "#####", "######" },
    fallback = "*",
    branch = "├─ ",
    last = "└─ ",
    vertical = "│  ",
  },
  elements = {
    task = { done = "[x]", todo = "[ ]", states = {}, state_hls = {} },
    code = { glyph = "", lang_glyph = false },
    callout = { glyph = "!", types = {}, type_hls = {} },
    table = { glyph = "#" },
    image = { glyph = "img" },
    link = { glyph = "@" },
    bullet = { glyph = "•" },
  },
}

return M
