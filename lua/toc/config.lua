local M = {}

M.defaults = {
  -- Panel width: a fixed column count, or "auto" to fit the longest line.
  width = 34,
  -- Extra columns added beside the content when width = "auto".
  padding = 2,
  -- Upper bound for the auto width (content past this is truncated).
  width_max = 60,
  -- Which side the TOC opens on: "right" | "left".
  position = "right",
  -- Follow the cursor: moving in the TOC moves the source cursor.
  follow_cursor = true,
  -- Reverse follow: moving in the source highlights the active entry.
  follow_source = true,
  -- Keep the TOC focused after opening (false = stay in the source).
  focus_on_open = true,
  -- Close the TOC after selecting an entry with <CR>.
  close_on_select = false,
  -- Live-refresh the TOC as the source buffer changes.
  auto_refresh = true,
  -- Debounce (ms) for live refresh; 0 refreshes on every change. Saving is always immediate.
  refresh_debounce = 150,
  -- A named bundle from toc.presets ("compact"|"boxed"|"minimal"|"writing"|"plain"),
  -- or an inline partial config table. Layered under your explicit options.
  preset = nil,
  -- Borrow heading/checkbox glyphs from markview.nvim when it is available.
  markview = true,
  -- Auto-open the TOC when entering a matching buffer.
  auto_enabled = true,
  -- Auto-close the TOC when the window switches to a non-markdown file.
  auto_close = true,
  -- Filetypes that auto_enabled and buffer-switch tracking react to.
  filetypes = { "markdown", "quarto", "rmd", "mdx", "help" },

  -- Display mode:
  --   "full"       glyph + number + text
  --   "glyph-only" glyph + number (text hidden)
  --   "text-only"  number + text (glyph hidden)
  --   "minimal"    glyph only
  mode = "full",
  -- Heading numbering:
  --   "level"  <level>.<nth-at-level>  (H1 → 1.1, H2 → 2.1, 2.2)
  --   "nested" hierarchical outline     (1, 1.1, 1.1.1)
  --   "flat"   running count            (1, 2, 3)
  --   false    no numbers
  numbers = "level",
  -- Show label prefixes ("heading", "task", "anchor", …); false = numbers/indices only.
  labels = true,
  -- Truncate text that would overflow the panel width with "…".
  truncate = true,
  -- Indent (spaces) added per depth when guides = false.
  indent = 2,
  -- Draw tree guide lines connecting nested entries.
  guides = true,
  -- Header text at the top of the panel; false hides it.
  title = "󰠶 Table of Contents",

  -- One block per element kind: enable it, its glyph, and its label prefix.
  -- Headings use the per-level `glyphs.heading` array; other kinds use `glyph`.
  -- Tasks use `done`/`todo` glyphs. Callouts label themselves by type (note/warning/…).
  elements = {
    heading = { enable = true, label = "heading" },
    task = { enable = true, label = "task", done = "", todo = "", states = {}, state_hls = {} },
    code = { enable = true, label = "code", glyph = "", lang_glyph = true },
    callout = { enable = true, glyph = "", types = {}, type_hls = {} },
    table = { enable = true, label = "table", glyph = "" },
    image = { enable = true, label = "image", glyph = "" },
    link = { enable = false, label = "anchor", glyph = "" },
    bullet = { enable = false, label = "item", glyph = "" },
  },

  -- Structural glyphs: per-level heading icons, the tree connectors, and a fallback.
  glyphs = {
    heading = { "󰼏", "󰼐", "󰼑", "󰼒", "󰼓", "󰼔" },
    fallback = "󰗨",
    branch = "├╴",
    last = "╰╴",
    vertical = "│ ",
  },

  -- Highlight group per heading level.
  highlights = {
    "TocHeading1",
    "TocHeading2",
    "TocHeading3",
    "TocHeading4",
    "TocHeading5",
    "TocHeading6",
  },

  -- Movement feedback.
  effects = {
    -- Flash the target line in the source window on jump/follow.
    -- priority sits above Neovim's default (4096) so the flash wins over
    -- heavy decorators like markview on heading lines.
    beacon = { enable = true, hl = "TocBeacon", duration = 250, fade_steps = 8, priority = 10000 },
    -- Marker beside the active entry inside the TOC.
    active_sign = { enable = true, text = "", hl = "TocActiveSign" },
    -- Line highlight on the active entry inside the TOC.
    active_line = { enable = true, hl = "TocActiveLine" },
  },

  -- Window-local options for the TOC buffer.
  window = {
    number = false,
    relativenumber = false,
    wrap = false,
    cursorline = true,
    signcolumn = "yes:1",
    foldcolumn = "0",
    winfixwidth = true,
  },

  -- Buffer-local keymaps inside the TOC window.
  keymaps = {
    jump = "<CR>",
    jump_stay = "o",
    close = "q",
    refresh = "R",
    next = "J",
    prev = "K",
  },
}

M.options = vim.deepcopy(M.defaults)

---@param s any
---@return string|nil
local function trim(s)
  if type(s) ~= "string" then
    return nil
  end
  s = s:gsub("%s+$", "")
  return s ~= "" and s or nil
end

---Derive heading/checkbox glyphs from markview.nvim's resolved config.
---@return table|nil
local function derive_markview()
  local ok, spec = pcall(require, "markview.spec")
  if not ok or type(spec.get) ~= "function" then
    return nil
  end
  -- markview resolves module configs lazily through spec.get(), not spec.config.
  local function get(...)
    local okg, v = pcall(spec.get, { ... })
    return okg and type(v) == "table" and v or nil
  end
  local derived = {}

  local hs = get("markdown", "headings")
  if type(hs) == "table" then
    local heading = {}
    for i = 1, 6 do
      local hi = hs["heading_" .. i]
      if type(hi) == "table" then
        heading[i] = trim(hi.sign) or trim(hi.icon)
      end
    end
    if next(heading) then
      derived.glyphs = { heading = heading }
    end
  end

  local elements = {}

  local cb = get("markdown_inline", "checkboxes")
  if type(cb) == "table" then
    local task = {}
    local states = {}
    local state_hls = {}
    for key, def in pairs(cb) do
      if type(def) == "table" and type(def.text) == "string" then
        if key == "checked" then
          task.done = trim(def.text)
        elseif key == "unchecked" then
          task.todo = trim(def.text)
        elseif #key == 1 then
          -- Custom state such as "/", ">", "?" keyed by the char inside [ ].
          states[key] = trim(def.text)
          if type(def.hl) == "string" then
            state_hls[key] = def.hl
          end
        end
      end
    end
    if next(states) then
      task.states = states
    end
    if next(state_hls) then
      task.state_hls = state_hls
    end
    if next(task) then
      elements.task = task
    end
  end

  -- Callout icons/colours keyed by type ("NOTE", "WARNING", …) → lowercased.
  local bq = get("markdown", "block_quotes")
  if type(bq) == "table" then
    local types = {}
    local type_hls = {}
    for key, def in pairs(bq) do
      if type(def) == "table" and type(def.icon) == "string" then
        types[key:lower()] = trim(def.icon)
        if type(def.hl) == "string" then
          type_hls[key:lower()] = def.hl
        end
      end
    end
    if next(types) then
      elements.callout = { types = types, type_hls = type_hls }
    end
  end

  if next(elements) then
    derived.elements = elements
  end

  return next(derived) and derived or nil
end

---Resolve `preset` (a name or an inline table) to a partial config.
---@param preset any
---@return table
local function resolve_preset(preset)
  if type(preset) == "string" then
    local ok, presets = pcall(require, "toc.presets")
    return (ok and type(presets[preset]) == "table") and presets[preset] or {}
  elseif type(preset) == "table" then
    return preset
  end
  return {}
end

---@param opts toc.Config|nil partial configuration, deep-merged over the defaults
function M.setup(opts)
  ---@type table<string, any>
  local o = opts or {}
  local preset = resolve_preset(o.preset)

  -- markview applies unless disabled by the user or the chosen preset.
  local mv_flag = o.markview
  if mv_flag == nil then
    mv_flag = preset.markview
  end
  if mv_flag == nil then
    mv_flag = M.defaults.markview
  end

  -- Layer order: defaults < markview-derived < preset < explicit user options.
  local merged = vim.deepcopy(M.defaults)
  if mv_flag ~= false then
    local mv = derive_markview()
    if mv then
      merged = vim.tbl_deep_extend("force", merged, mv)
    end
  end
  merged = vim.tbl_deep_extend("force", merged, preset)
  M.options = vim.tbl_deep_extend("force", merged, o)
  return M.options
end

return M
