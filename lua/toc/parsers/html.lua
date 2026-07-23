local Parser = require "toc.parsers.base"
local h = require "toc.parsers.html_utils"

-- Full html-buffer parser: treesitter for structure, a line scanner as the
-- fallback. Line-level extraction lives in html_utils (shared with markdown).
---@class Html : Parser
local Html = setmetatable({}, { __index = Parser })
Html.__index = Html

---@param bufnr integer
---@return Html
function Html.new(bufnr)
  return setmetatable(Parser.new(bufnr), Html) --[[@as Html]]
end

-- Compiled (tag_name) treesitter query, built once and reused across parses.
local tag_query

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
---@return boolean ran true when the html treesitter parser was available
function Html:treesitter()
  local ok, obj = pcall(vim.treesitter.get_parser, self.bufnr, "html")
  if not ok or not obj then
    return false
  end
  local ok_tree, tree = pcall(function()
    return obj:parse()[1]
  end)
  if not ok_tree or not tree then
    return false
  end
  if not tag_query then
    local ok_q, q = pcall(vim.treesitter.query.parse, "html", "(tag_name) @tag")
    if not ok_q then
      return false
    end
    tag_query = q
  end

  for _, node in tag_query:iter_captures(tree:root(), self.bufnr, 0, -1) do
    local container = node:parent() -- start_tag / self_closing_tag / end_tag
    if container and container:type() ~= "end_tag" then
      local tag = vim.treesitter.get_node_text(node, self.bufnr):lower()
      local lnum = container:start() + 1
      local element = container:parent()
      local inner = (element and element:type() == "element")
          and h.flatten(vim.treesitter.get_node_text(element, self.bufnr))
        or ""
      local hn = tag:match "^h([1-6])$"

      if hn then
        self.head_level = tonumber(hn) or self.head_level
        if self:enabled "heading" then
          self:add {
            lnum = lnum,
            level = self.head_level,
            kind = "heading",
            text = inner ~= "" and inner or "(untitled)",
          }
        end
      elseif tag == "img" and self:enabled "image" then
        local tt = vim.treesitter.get_node_text(container, self.bufnr)
        self:add { lnum = lnum, level = self:child_level(), kind = "image", text = h.img_label(tt) }
      elseif tag == "a" and self:enabled "link" then
        local text = inner
        if text == "" then
          text = h.attr(vim.treesitter.get_node_text(container, self.bufnr), "href") or "link"
        end
        self:add { lnum = lnum, level = self:child_level(), kind = "link", text = text }
      elseif tag == "table" and self:enabled "table" then
        local tt = (element and element:type() == "element") and vim.treesitter.get_node_text(element, self.bufnr) or ""
        self:add { lnum = lnum, level = self:child_level(), kind = "table", text = h.table_label(tt) }
      elseif TS_KIND[tag] and self:enabled(TS_KIND[tag]) then
        local kind = TS_KIND[tag]
        local text = kind == "code" and "code" or (inner ~= "" and inner or kind)
        local entry = { lnum = lnum, level = self:child_level(), kind = kind, text = text }
        if kind == "callout" then
          entry.label = "quote"
        end
        self:add(entry)
      end
    end
  end
  return true
end

---Line scanner for when the html treesitter parser is unavailable.
function Html:regex()
  local lines = self:lines()
  local skip_until = 0
  for i, line in ipairs(lines) do
    if i <= skip_until then
      goto continue
    end
    local hlvl, htext = h.heading(line)
    if hlvl then
      self.head_level = hlvl
      if self:enabled "heading" then
        self:add { lnum = i, level = self.head_level, kind = "heading", text = htext ~= "" and htext or "(untitled)" }
      end
    elseif self:enabled "table" and line:match "^%s*<[Tt][Aa][Bb][Ll][Ee][%s>]" then
      -- <table> spans lines; consume to its close (or end-of-buffer) so cells
      -- are not re-scanned, and label it from the caption/first <th>.
      local parts, close = { line }, nil
      for j = i + 1, #lines do
        parts[#parts + 1] = lines[j]
        if lines[j]:match "</[Tt][Aa][Bb][Ll][Ee]>" then
          close = j
          break
        end
      end
      skip_until = close or #lines
      self:add { lnum = i, level = self:child_level(), kind = "table", text = h.table_label(table.concat(parts, "\n")) }
    elseif self:enabled "code" and line:match "^%s*<[Pp][Rr][Ee][%s>]" then
      -- <pre> block → a single "code" entry (matches the treesitter path).
      local close
      for j = i, #lines do
        if lines[j]:match "</[Pp][Rr][Ee]>" then
          close = j
          break
        end
      end
      skip_until = close or #lines
      self:add { lnum = i, level = self:child_level(), kind = "code", text = "code" }
    elseif self:enabled "callout" and line:match "^%s*<[Bb][Ll][Oo][Cc][Kk][Qq][Uu][Oo][Tt][Ee][%s>]" then
      -- <blockquote> block → a callout labelled from its flattened text.
      -- Start at line i so a single-line <blockquote>…</blockquote> closes here.
      local parts, close = {}, nil
      for j = i, #lines do
        parts[#parts + 1] = lines[j]
        if lines[j]:match "</[Bb][Ll][Oo][Cc][Kk][Qq][Uu][Oo][Tt][Ee]>" then
          close = j
          break
        end
      end
      skip_until = close or #lines
      local text = h.flatten(table.concat(parts, " "))
      self:add {
        lnum = i,
        level = self:child_level(),
        kind = "callout",
        text = text ~= "" and text or "quote",
        label = "quote",
      }
    else
      if self:enabled "bullet" then
        for _, text in ipairs(h.list_items(line)) do
          self:add { lnum = i, level = self:child_level(), kind = "bullet", text = text }
        end
      end
      if self:enabled "link" then
        for _, text in ipairs(h.links(line)) do
          self:add { lnum = i, level = self:child_level(), kind = "link", text = text }
        end
      end
      if self:enabled "image" then
        for _, text in ipairs(h.images(line)) do
          self:add { lnum = i, level = self:child_level(), kind = "image", text = text }
        end
      end
      if self:enabled "summary" then
        for _, text in ipairs(h.summaries(line)) do
          self:add { lnum = i, level = self:child_level(), kind = "summary", text = text }
        end
      end
      if self:enabled "definition" then
        for _, text in ipairs(h.terms(line)) do
          self:add { lnum = i, level = self:child_level(), kind = "definition", text = text }
        end
      end
    end
    ::continue::
  end
end

---Parse an HTML buffer (treesitter when available, else a line scanner).
---@return TocEntry[]
function Html:parse()
  if not self:treesitter() then
    self:regex()
  end
  return self.entries
end

return Html
