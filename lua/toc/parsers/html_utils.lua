-- Line-level HTML extraction shared by the markdown parser (inline HTML) and
-- the html filetype parser. Pure string work: no config, no buffer I/O.
local M = {}

---A case-insensitive pattern fragment for a literal tag name ("a" -> "[Aa]").
---@param tag string
---@return string
local function ci(tag)
  return (tag:gsub("%a", function(c)
    return "[" .. c:upper() .. c:lower() .. "]"
  end))
end

-- Precomputed tag patterns (built once; case-insensitive, void- or paired-tag).
local P_IMG = "<" .. ci "img" .. "%s[^>]*>"
local P_A = "(<" .. ci "a" .. "%s[^>]*>)(.-)</" .. ci "a" .. ">"
local P_SUMMARY = "<" .. ci "summary" .. "[^>]*>(.-)</" .. ci "summary" .. ">"
local P_DT = "<" .. ci "dt" .. "[^>]*>(.-)</" .. ci "dt" .. ">"
local P_CAPTION = "<" .. ci "caption" .. "[^>]*>(.-)</" .. ci "caption" .. ">"
local P_TH = "<" .. ci "th" .. "[^>]*>(.-)</" .. ci "th" .. ">"
local P_LI = "<" .. ci "li" .. "[^>]*>(.-)</" .. ci "li" .. ">"

---@param tagtext string a single tag's source ("<img alt='x' ...>")
---@param name string attribute name
---@return string|nil
function M.attr(tagtext, name)
  -- The leading %s keeps `alt` from matching inside `data-alt`, etc.
  return tagtext:match("%s" .. name .. '%s*=%s*"([^"]*)"') or tagtext:match("%s" .. name .. "%s*=%s*'([^']*)'")
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

---Alt text, else the src filename, else "image", for one `<img>` tag's source.
---@param tagtext string
---@return string
function M.img_label(tagtext)
  local alt = M.attr(tagtext, "alt")
  if alt and alt ~= "" then
    return alt
  end
  local src = M.attr(tagtext, "src")
  return (src and src:match "([^/]+)$") or "image"
end

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
  for tag in line:gmatch(P_IMG) do
    out[#out + 1] = M.img_label(tag)
  end
  return out
end

---Text (or href fallback) for each `<a ...>...</a>` on the line.
---@param line string
---@return string[]
function M.links(line)
  local out = {}
  for tag, inner in line:gmatch(P_A) do
    local text = M.flatten(inner)
    out[#out + 1] = text ~= "" and text or (M.attr(tag, "href") or "link")
  end
  return out
end

---Title of each `<summary>...</summary>` (a `<details>` disclosure) on the line.
---@param line string
---@return string[]
function M.summaries(line)
  local out = {}
  for inner in line:gmatch(P_SUMMARY) do
    local text = M.flatten(inner)
    out[#out + 1] = text ~= "" and text or "summary"
  end
  return out
end

---Text of each `<dt>...</dt>` (definition-list term) on the line.
---@param line string
---@return string[]
function M.terms(line)
  local out = {}
  for inner in line:gmatch(P_DT) do
    local text = M.flatten(inner)
    out[#out + 1] = text ~= "" and text or "term"
  end
  return out
end

---Caption of a `<table>`: its `<caption>`, else the first `<th>`, else "table".
---@param html_text string the table element's source
---@return string
function M.table_label(html_text)
  local cap = M.flatten(html_text:match(P_CAPTION) or "")
  if cap ~= "" then
    return cap
  end
  local th = M.flatten(html_text:match(P_TH) or "")
  if th ~= "" then
    return th
  end
  return "table"
end

---Text of each `<li>...</li>` (list item) on the line.
---@param line string
---@return string[]
function M.list_items(line)
  local out = {}
  for inner in line:gmatch(P_LI) do
    local text = M.flatten(inner)
    out[#out + 1] = text ~= "" and text or "item"
  end
  return out
end

return M
