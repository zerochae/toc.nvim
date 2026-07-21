local config = require "toc.config"

local M = {}

local DEFAULT = "toc.parsers.markdown"

-- Parser modules keyed by filetype; markdown handles the rest (quarto/rmd/mdx…).
local by_filetype = {
  markdown = "toc.parsers.markdown",
  help = "toc.parsers.help",
  html = "toc.parsers.html",
}

---Parse `bufnr` into sorted TOC entries, dispatching on its filetype.
---@param bufnr integer
---@return TocEntry[]
function M.parse(bufnr)
  local ft = vim.bo[bufnr].filetype
  local entries = require(by_filetype[ft] or DEFAULT).new(bufnr):parse()

  table.sort(entries, function(a, b)
    if a.lnum ~= b.lnum then
      return a.lnum < b.lnum
    end
    if a.level ~= b.level then
      return a.level < b.level
    end
    return (a.ord or 0) < (b.ord or 0)
  end)

  local max = config.options.max_level
  if max then
    entries = vim.tbl_filter(function(e)
      return e.level <= max
    end, entries)
  end
  return entries
end

return M
