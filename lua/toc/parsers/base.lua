local config = require "toc.config"

-- Base class for the per-filetype parsers. A subclass sets its own metatable
-- with `__index = Parser`, adds a `new(bufnr)` that calls `Parser.new`, and
-- implements `parse()` returning `self.entries`.
---@class Parser
---@field bufnr integer
---@field entries TocEntry[]
---@field head_level integer level of the most recent heading (0 before any)
local Parser = {}
Parser.__index = Parser

---@param bufnr integer
---@return Parser
function Parser.new(bufnr)
  return setmetatable({ bufnr = bufnr, entries = {}, head_level = 0 }, Parser)
end

---The buffer's lines.
---@return string[]
function Parser:lines()
  return vim.api.nvim_buf_get_lines(self.bufnr, 0, -1, false)
end

---Append an entry, stamping insertion order for a stable sort.
---@param entry TocEntry
function Parser:add(entry)
  entry.ord = #self.entries + 1
  self.entries[#self.entries + 1] = entry
end

---Is the element kind indexed under the current config?
---@param kind string
---@return boolean
function Parser:enabled(kind)
  local el = config.options.elements[kind]
  return el ~= nil and el.enable
end

---Non-heading elements nest one level below the current heading.
---@param extra? integer additional depth (e.g. bullet indent)
---@return integer
function Parser:child_level(extra)
  return self.head_level + 1 + (extra or 0)
end

return Parser
