local M = {}

-- Parser modules keyed by filetype; markdown is the default.
local by_filetype = {
  help = "toc.parsers.help",
}

---Parse `bufnr` into sorted TOC entries, dispatching on its filetype.
---@param bufnr integer
---@return TocEntry[]
function M.parse(bufnr)
  local ft = vim.bo[bufnr].filetype
  local entries = require(by_filetype[ft] or "toc.parsers.markdown").parse(bufnr)

  table.sort(entries, function(a, b)
    if a.lnum ~= b.lnum then
      return a.lnum < b.lnum
    end
    if a.level ~= b.level then
      return a.level < b.level
    end
    return (a.ord or 0) < (b.ord or 0)
  end)
  return entries
end

return M
