local config = require "toc.config"

-- Pure entry -> display computation: turns parsed entries into buffer lines,
-- highlight marks, and the line<->entry index maps. No window or buffer I/O.
local M = {}

---@class TocMark
---@field line integer 0-based buffer line
---@field col integer byte start column
---@field end_col integer byte end column
---@field hl string highlight group

local lang_hl_cache = {}

---Icon + coloured highlight group for a fenced-code language via
---nvim-web-devicons, if available. Returns "" (and nil) when it is not.
---@param lang string
---@return string icon, string|nil hl
local function lang_deco(lang)
  local ok, devicons = pcall(require, "nvim-web-devicons")
  if not ok then
    return "", nil
  end
  local icon, color = devicons.get_icon_color_by_filetype(lang, { default = false })
  if not icon then
    return "", nil
  end
  local hl
  if color then
    hl = "TocLang_" .. lang
    if not lang_hl_cache[hl] then
      pcall(vim.api.nvim_set_hl, 0, hl, { fg = color, default = true })
      lang_hl_cache[hl] = true
    end
  end
  return icon, hl
end

---Shallowest heading level present (defaults to 1 when empty).
---@param entries TocEntry[]
---@return integer
local function min_level(entries)
  local m = 6
  for _, h in ipairs(entries) do
    m = math.min(m, h.level)
  end
  return #entries > 0 and m or 1
end

---Does entry `i` have a later sibling at `level` before the branch closes?
---@param entries TocEntry[]
---@param i integer
---@param level integer
---@return boolean
local function has_following_sibling(entries, i, level)
  for j = i + 1, #entries do
    if entries[j].level < level then
      return false
    end
    if entries[j].level == level then
      return true
    end
  end
  return false
end

---Build the tree-guide prefix for an entry.
---@param entries TocEntry[]
---@param i integer
---@param base integer shallowest level present
---@return string
local function build_prefix(entries, i, base)
  local opts = config.options
  local level = entries[i].level

  -- Top-level (root) entries carry no tree connector.
  if level <= base then
    return ""
  end

  if not opts.guides then
    return string.rep(" ", (level - base) * opts.indent)
  end

  -- Blank ancestor columns must match the vertical guide's display width.
  local blank = string.rep(" ", vim.fn.strdisplaywidth(opts.glyphs.vertical))
  local parts = {}
  for d = base + 1, level - 1 do
    parts[#parts + 1] = has_following_sibling(entries, i, d) and opts.glyphs.vertical or blank
  end
  parts[#parts + 1] = has_following_sibling(entries, i, level) and opts.glyphs.branch or opts.glyphs.last
  return table.concat(parts)
end

---@param level integer
---@return string
local function heading_hl(level)
  return config.options.highlights[level] or ("TocHeading" .. math.min(level, 6))
end

local KIND_HL = {
  code = "TocCode",
  callout = "TocCallout",
  table = "TocTable",
  image = "TocImage",
  link = "TocLink",
  bullet = "TocBullet",
  summary = "TocSummary",
  definition = "TocDefinition",
}

---@param e TocEntry
---@return string
local function entry_glyph(e)
  local g = config.options.glyphs
  local el = config.options.elements
  if e.kind == "heading" then
    return g.heading[e.level] or g.heading[#g.heading] or g.fallback
  elseif e.kind == "task" then
    local t = el.task
    local st = e.state or (e.done and "x" or " ")
    if st == " " then
      return t.todo
    elseif st == "x" or st == "X" then
      return t.done
    end
    return (t.states and t.states[st]) or t.done
  elseif e.kind == "callout" then
    local co = el.callout
    return (co.types and e.label and co.types[e.label]) or co.glyph or g.fallback
  end
  local spec = el[e.kind]
  return (spec and spec.glyph) or g.fallback
end

---@param e TocEntry
---@return string
local function entry_hl(e)
  if e.kind == "heading" then
    return heading_hl(e.level)
  elseif e.kind == "task" then
    local t = config.options.elements.task
    local st = e.state or (e.done and "x" or " ")
    if st == " " then
      return "TocTask"
    elseif st == "x" or st == "X" then
      return "TocTaskDone"
    end
    return (t.state_hls and t.state_hls[st]) or "TocTaskDone"
  elseif e.kind == "callout" then
    local co = config.options.elements.callout
    return (co.type_hls and e.label and co.type_hls[e.label]) or "TocCallout"
  end
  return KIND_HL[e.kind] or "TocText"
end

---Columns reserved by the sign gutter, derived from the signcolumn setting.
---@return integer
function M.sign_width()
  local sc = config.options.window.signcolumn or "no"
  if sc:match "^yes" or sc:match "^auto" or sc:match "^number" then
    return 2 * (tonumber(sc:match ":(%d+)") or 1)
  end
  return 0
end

---Truncate `text` to `avail` display cells, appending an ellipsis when cut.
---@param text string
---@param avail integer
---@return string
local function fit_text(text, avail)
  if not config.options.truncate or avail <= 0 then
    return text
  end
  if vim.fn.strdisplaywidth(text) <= avail then
    return text
  end
  local ell = "…"
  local budget = avail - vim.fn.strdisplaywidth(ell)
  if budget <= 0 then
    return ell
  end
  local take = 0
  for i = 1, vim.fn.strchars(text) do
    if vim.fn.strdisplaywidth(vim.fn.strcharpart(text, 0, i)) <= budget then
      take = i
    else
      break
    end
  end
  return vim.fn.strcharpart(text, 0, take) .. ell
end

---Compute the number/label string per entry, plus optional icon decorations.
---@param entries TocEntry[]
---@param base integer shallowest level present
---@return string[] labels, table<integer, table> decos
local function compute_numbers(entries, base)
  local mode = config.options.numbers
  local els = config.options.elements
  local out = {}
  local decos = {}
  local kind_count = {}

  -- Join a label and number with a single space; number only when unlabelled.
  local function labelled(prefix, num)
    if prefix == "" then
      return tostring(num)
    end
    return prefix .. " " .. num
  end
  -- Non-heading entries get a direct "<label> <n>" identity (e.g. "anchor 1").
  -- A per-instance `label` (e.g. callout type) counts and prefixes on its own.
  -- Returns the label and, for code, an optional { hl, col, len } for the
  -- language icon so the renderer can colour just that glyph.
  local show_labels = config.options.labels ~= false
  local function element_label(e)
    local spec = els[e.kind]
    -- Count per real prefix (kind/callout type); only the display is gated.
    local key = e.label or (spec and spec.label) or e.kind
    kind_count[key] = (kind_count[key] or 0) + 1
    local label = labelled(show_labels and key or "", kind_count[key])
    if e.kind == "code" and e.text ~= "" and e.text ~= "code" then
      local icon, hl = "", nil
      if not spec or spec.lang_glyph ~= false then
        icon, hl = lang_deco(e.text)
      end
      local deco = icon ~= "" and hl and { hl = hl, col = #label + 2, len = #icon } or nil
      label = label .. " [" .. (icon ~= "" and icon .. " " or "") .. e.text .. "]"
      return label, deco
    end
    return label
  end
  local head_prefix = show_labels and ((els.heading and els.heading.label) or "") or ""

  if not mode or mode == "none" then
    for i, h in ipairs(entries) do
      if h.kind == "heading" then
        out[i] = ""
      else
        out[i], decos[i] = element_label(h)
      end
    end
    return out, decos
  end
  if mode == "flat" then
    local n = 0
    for i, h in ipairs(entries) do
      if h.kind == "heading" then
        n = n + 1
        out[i] = labelled(head_prefix, n)
      else
        out[i], decos[i] = element_label(h)
      end
    end
    return out, decos
  end
  if mode == "level" then
    local per_level = {}
    for i, h in ipairs(entries) do
      if h.kind == "heading" then
        per_level[h.level] = (per_level[h.level] or 0) + 1
        out[i] = labelled(head_prefix, h.level .. "." .. per_level[h.level])
      else
        out[i], decos[i] = element_label(h)
      end
    end
    return out, decos
  end
  local counters = {}
  for i, h in ipairs(entries) do
    if h.kind == "heading" then
      counters[h.level] = (counters[h.level] or 0) + 1
      for l = h.level + 1, 6 do
        counters[l] = nil
      end
      local parts = {}
      for l = base, h.level do
        parts[#parts + 1] = counters[l] or 1
      end
      out[i] = labelled(head_prefix, table.concat(parts, "."))
    else
      out[i], decos[i] = element_label(h)
    end
  end
  return out, decos
end

---Resolve which segments a display mode renders.
---@param mode string
---@return boolean glyph, boolean number, boolean text
local function mode_segments(mode)
  if mode == "glyph-only" then
    return true, true, false
  elseif mode == "text-only" then
    return false, true, true
  elseif mode == "minimal" then
    return true, false, false
  end
  return true, true, true
end

---Turn parsed entries into buffer lines, highlight marks and index maps.
---@param entries TocEntry[]
---@return string[] lines, TocMark[] marks, table line_to_entry, table entry_to_line
function M.build(entries)
  local opts = config.options
  local base = min_level(entries)
  local numbers, decos = compute_numbers(entries, base)
  local show_glyph, show_number, show_text = mode_segments(opts.mode)
  local cap = (opts.width == "auto") and (opts.width_max or 60) or opts.width
  local avail_base = cap - M.sign_width()

  local lines, marks = {}, {}
  local line_to_entry, entry_to_line = {}, {}

  if opts.title then
    lines[#lines + 1] = " " .. opts.title
    marks[#marks + 1] = { line = 0, col = 0, end_col = #lines[1], hl = "TocTitle" }
    lines[#lines + 1] = ""
  end

  for i, h in ipairs(entries) do
    local prefix = build_prefix(entries, i, base)
    local lnum = #lines
    local line = prefix
    local col = #prefix

    local function append(str, hl)
      if str == "" then
        return
      end
      if col > #prefix then
        line = line .. " "
        col = col + 1
      end
      local start = col
      line = line .. str
      col = col + #str
      marks[#marks + 1] = { line = lnum, col = start, end_col = col, hl = hl }
    end

    marks[#marks + 1] = { line = lnum, col = 0, end_col = #prefix, hl = "TocGuide" }
    if show_glyph then
      append(entry_glyph(h), entry_hl(h))
    end
    if show_number then
      append(numbers[i], "TocNumber")
      -- Recolour just the language icon inside a code label.
      local d = decos[i]
      if d and numbers[i] ~= "" then
        local m = marks[#marks]
        local seg_start, seg_end = m.col, m.end_col
        local ic_start = seg_start + d.col
        m.end_col = ic_start
        marks[#marks + 1] = { line = lnum, col = ic_start, end_col = ic_start + d.len, hl = d.hl }
        marks[#marks + 1] = { line = lnum, col = ic_start + d.len, end_col = seg_end, hl = "TocNumber" }
      end
    end
    -- Code shows its language in the label, so skip the duplicate text segment.
    if show_text and h.kind ~= "code" then
      local raw = h.text ~= "" and h.text or "(untitled)"
      local used = vim.fn.strdisplaywidth(line) + (col > #prefix and 1 or 0)
      append(fit_text(raw, avail_base - used), "TocText")
    end

    lines[#lines + 1] = line
    line_to_entry[lnum + 1] = i
    entry_to_line[i] = lnum + 1
  end

  if #entries == 0 then
    lines[#lines + 1] = " No headings found"
    marks[#marks + 1] = { line = #lines - 1, col = 0, end_col = #lines[#lines], hl = "TocGuide" }
  end

  return lines, marks, line_to_entry, entry_to_line
end

return M
