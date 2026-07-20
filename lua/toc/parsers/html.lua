local config = require "toc.config"

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
local function attr(tagtext, name)
  return tagtext:match(name .. '%s*=%s*"([^"]*)"') or tagtext:match(name .. "%s*=%s*'([^']*)'")
end

---Strip tags/entities and collapse whitespace to a plain title.
---@param s string
---@return string
local function flatten(s)
  s = s:gsub("<[^>]*>", " ")
  s = s:gsub("%s+", " ")
  s = s:gsub("^%s+", "")
  s = s:gsub("%s+$", "")
  return s
end

-- Attributes and inner text come from each element's own (small) source text,
-- where a regex is reliable; treesitter only supplies structure and position.
---@param bufnr integer
---@return TocEntry[]|nil nil if the html parser is unavailable
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
      local hn = tag:match "^h([1-6])$"
      if hn then
        head_level = tonumber(hn) or head_level
        if enabled "heading" then
          local text = (element and element:type() == "element") and flatten(vim.treesitter.get_node_text(element, bufnr))
            or ""
          add { lnum = lnum, level = head_level, kind = "heading", text = text ~= "" and text or "(untitled)" }
        end
      elseif tag == "a" and enabled "link" then
        local text = (element and element:type() == "element") and flatten(vim.treesitter.get_node_text(element, bufnr))
          or ""
        if text == "" then
          text = attr(vim.treesitter.get_node_text(container, bufnr), "href") or "link"
        end
        add { lnum = lnum, level = head_level + 1, kind = "link", text = text }
      elseif tag == "img" and enabled "image" then
        local tt = vim.treesitter.get_node_text(container, bufnr)
        local alt = attr(tt, "alt")
        if not alt or alt == "" then
          local src = attr(tt, "src")
          alt = (src and src:match "([^/]+)$") or "image"
        end
        add { lnum = lnum, level = head_level + 1, kind = "image", text = alt }
      end
    end
  end
  return entries
end

-- Line-based fallback for when the html treesitter parser is unavailable;
-- handles the common single-line cases.
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
    for hn, inner in line:gmatch "<[Hh]([1-6])[^>]*>(.-)</[Hh][1-6]>" do
      head_level = tonumber(hn) or head_level
      if enabled "heading" then
        local text = flatten(inner)
        add { lnum = i, level = head_level, kind = "heading", text = text ~= "" and text or "(untitled)" }
      end
    end
    if enabled "link" then
      for tag, inner in line:gmatch "(<[Aa]%s[^>]*>)(.-)</[Aa]>" do
        local text = flatten(inner)
        if text == "" then
          text = attr(tag, "href") or "link"
        end
        add { lnum = i, level = head_level + 1, kind = "link", text = text }
      end
    end
    if enabled "image" then
      for tag in line:gmatch "<[Ii][Mm][Gg]%s[^>]*>" do
        local alt = attr(tag, "alt")
        if not alt or alt == "" then
          local src = attr(tag, "src")
          alt = (src and src:match "([^/]+)$") or "image"
        end
        add { lnum = i, level = head_level + 1, kind = "image", text = alt }
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
