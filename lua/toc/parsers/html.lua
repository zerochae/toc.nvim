local config = require "toc.config"

-- HTML extraction shared by the markdown parser (inline HTML) and the html
-- filetype parser. `heading`/`images`/`links` are line-level regex helpers;
-- `parse` is the full html-buffer parser (treesitter, regex fallback).
local M = {}

---@param kind string
---@return boolean
local function enabled(kind)
  local el = config.options.elements[kind]
  return el ~= nil and el.enable
end

---@param tagtext string a single tag's source ("<img alt='x' ...>")
---@param name string attribute name
---@return string|nil
function M.attr(tagtext, name)
  return tagtext:match(name .. '%s*=%s*"([^"]*)"') or tagtext:match(name .. "%s*=%s*'([^']*)'")
end

---Strip tags and collapse whitespace to a plain title.
---@param s string
---@return string
function M.flatten(s)
  s = s:gsub("<[^>]*>", " ")
  s = s:gsub("%s+", " ")
  s = s:gsub("^%s+", "")
  s = s:gsub("%s+$", "")
  return s
end

-- ── line-level helpers (also used for inline HTML inside markdown) ──────────

---A full-line `<hN ...>text</hN>` (or lone `<hN ...>`) heading.
---@param line string
---@return integer|nil level, string? text
function M.heading(line)
  local lvl, inner = line:match "^%s*<[Hh]([1-6])[^>]*>(.-)</[Hh][1-6]>"
  if not lvl then
    lvl, inner = line:match "^%s*<[Hh]([1-6])[^>]*>%s*$", ""
  end
  if not lvl then
    return nil
  end
  return tonumber(lvl), M.flatten(inner or "")
end

---Alt (or src filename) for each `<img>` on the line.
---@param line string
---@return string[]
function M.images(line)
  local out = {}
  for tag in line:gmatch "<[Ii][Mm][Gg]%s[^>]*>" do
    local alt = M.attr(tag, "alt")
    if not alt or alt == "" then
      local src = M.attr(tag, "src")
      alt = (src and src:match "([^/]+)$") or "image"
    end
    out[#out + 1] = alt
  end
  return out
end

---Text (or href fallback) for each `<a ...>...</a>` on the line.
---@param line string
---@return string[]
function M.links(line)
  local out = {}
  for tag, inner in line:gmatch "(<[Aa]%s[^>]*>)(.-)</[Aa]>" do
    local text = M.flatten(inner)
    if text == "" then
      text = M.attr(tag, "href") or "link"
    end
    out[#out + 1] = text
  end
  return out
end

---Title of each `<summary>...</summary>` (a `<details>` disclosure) on the line.
---@param line string
---@return string[]
function M.summaries(line)
  local out = {}
  for inner in line:gmatch "<[Ss][Uu][Mm][Mm][Aa][Rr][Yy][^>]*>(.-)</[Ss][Uu][Mm][Mm][Aa][Rr][Yy]>" do
    out[#out + 1] = M.flatten(inner) ~= "" and M.flatten(inner) or "summary"
  end
  return out
end

---Text of each `<dt>...</dt>` (definition-list term) on the line.
---@param line string
---@return string[]
function M.terms(line)
  local out = {}
  for inner in line:gmatch "<[Dd][Tt][^>]*>(.-)</[Dd][Tt]>" do
    out[#out + 1] = M.flatten(inner) ~= "" and M.flatten(inner) or "term"
  end
  return out
end

---Caption of a `<table>`: its `<caption>`, else the first `<th>`, else "table".
---@param html_text string the table element's source
---@return string
function M.table_label(html_text)
  local cap = html_text:match "<[Cc][Aa][Pp][Tt][Ii][Oo][Nn][^>]*>(.-)</[Cc][Aa][Pp][Tt][Ii][Oo][Nn]>"
  if cap and M.flatten(cap) ~= "" then
    return M.flatten(cap)
  end
  local th = html_text:match "<[Tt][Hh][^>]*>(.-)</[Tt][Hh]>"
  if th and M.flatten(th) ~= "" then
    return M.flatten(th)
  end
  return "table"
end

-- ── full html-buffer parsers ────────────────────────────────────────────────

-- tag_name -> element kind for tags whose title is just their flattened text.
-- <a>/<img> (need attrs) and <table> (needs a caption) have dedicated branches.
local TS_KIND = {
  blockquote = "callout",
  pre = "code",
  li = "bullet",
  summary = "summary",
  dt = "definition",
}

---Structure and positions from treesitter; attrs/text from each node's source.
---@param bufnr integer
---@return TocEntry[]|nil nil when the html parser is unavailable
local function parse_treesitter(bufnr)
  local ok, obj = pcall(vim.treesitter.get_parser, bufnr, "html")
  if not ok or not obj then
    return nil
  end
  local ok_tree, tree = pcall(function()
    return obj:parse()[1]
  end)
  if not ok_tree or not tree then
    return nil
  end
  local ok_q, query = pcall(vim.treesitter.query.parse, "html", "(tag_name) @tag")
  if not ok_q then
    return nil
  end

  local entries = {}
  local head_level = 0
  local function add(entry)
    entry.ord = #entries + 1
    entries[#entries + 1] = entry
  end

  for _, node in query:iter_captures(tree:root(), bufnr, 0, -1) do
    local container = node:parent() -- start_tag / self_closing_tag / end_tag
    if container and container:type() ~= "end_tag" then
      local tag = vim.treesitter.get_node_text(node, bufnr):lower()
      local lnum = container:start() + 1
      local element = container:parent()
      local inner = (element and element:type() == "element")
          and M.flatten(vim.treesitter.get_node_text(element, bufnr))
        or ""
      local hn = tag:match "^h([1-6])$"

      if hn then
        head_level = tonumber(hn) or head_level
        if enabled "heading" then
          add { lnum = lnum, level = head_level, kind = "heading", text = inner ~= "" and inner or "(untitled)" }
        end
      elseif tag == "img" and enabled "image" then
        local tt = vim.treesitter.get_node_text(container, bufnr)
        local alt = M.attr(tt, "alt")
        if not alt or alt == "" then
          local src = M.attr(tt, "src")
          alt = (src and src:match "([^/]+)$") or "image"
        end
        add { lnum = lnum, level = head_level + 1, kind = "image", text = alt }
      elseif tag == "a" and enabled "link" then
        local text = inner
        if text == "" then
          text = M.attr(vim.treesitter.get_node_text(container, bufnr), "href") or "link"
        end
        add { lnum = lnum, level = head_level + 1, kind = "link", text = text }
      elseif tag == "table" and enabled "table" then
        local tt = (element and element:type() == "element") and vim.treesitter.get_node_text(element, bufnr) or ""
        add { lnum = lnum, level = head_level + 1, kind = "table", text = M.table_label(tt) }
      elseif TS_KIND[tag] and enabled(TS_KIND[tag]) then
        local kind = TS_KIND[tag]
        local text = kind == "code" and "code" or (inner ~= "" and inner or kind)
        local entry = { lnum = lnum, level = head_level + 1, kind = kind, text = text }
        if kind == "callout" then
          entry.label = "quote"
        end
        add(entry)
      end
    end
  end
  return entries
end

---Line scanner for when the html treesitter parser is unavailable.
---@param bufnr integer
---@return TocEntry[]
local function parse_regex(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local entries = {}
  local head_level = 0
  local function add(entry)
    entry.ord = #entries + 1
    entries[#entries + 1] = entry
  end

  for i, line in ipairs(lines) do
    local hlvl, htext = M.heading(line)
    if hlvl then
      head_level = hlvl
      if enabled "heading" then
        add { lnum = i, level = head_level, kind = "heading", text = htext ~= "" and htext or "(untitled)" }
      end
    else
      if enabled "link" then
        for _, text in ipairs(M.links(line)) do
          add { lnum = i, level = head_level + 1, kind = "link", text = text }
        end
      end
      if enabled "image" then
        for _, text in ipairs(M.images(line)) do
          add { lnum = i, level = head_level + 1, kind = "image", text = text }
        end
      end
      if enabled "summary" then
        for _, text in ipairs(M.summaries(line)) do
          add { lnum = i, level = head_level + 1, kind = "summary", text = text }
        end
      end
      if enabled "definition" then
        for _, text in ipairs(M.terms(line)) do
          add { lnum = i, level = head_level + 1, kind = "definition", text = text }
        end
      end
    end
  end
  return entries
end

---Parse an HTML buffer (treesitter when available, else a line scanner).
---@param bufnr integer
---@return TocEntry[]
function M.parse(bufnr)
  return parse_treesitter(bufnr) or parse_regex(bufnr)
end

return M
