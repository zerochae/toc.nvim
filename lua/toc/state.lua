-- Shared, mutable view state for the single TOC panel.
local M = {
  src_buf = nil, -- source markdown buffer
  src_win = nil, -- source window
  toc_buf = nil, -- toc scratch buffer
  toc_win = nil, -- toc window
  headings = {}, -- TocEntry[]
  line_to_heading = {}, -- toc display line -> entry index
  heading_to_line = {}, -- entry index -> toc display line
  syncing = false, -- guard against follow feedback loops
}

M.ns = vim.api.nvim_create_namespace "toc.nvim"
M.ns_active = vim.api.nvim_create_namespace "toc.nvim.active"
M.augroup = vim.api.nvim_create_augroup("toc.nvim", { clear = true })
M.augroup_switch = vim.api.nvim_create_augroup("toc.nvim.switch", { clear = true })

---@return boolean
function M.is_open()
  return M.toc_win ~= nil and vim.api.nvim_win_is_valid(M.toc_win)
end

---Reset the transient view state after the TOC closes.
function M.reset()
  M.src_win = nil
  M.src_buf = nil
  M.toc_win = nil
  M.toc_buf = nil
  M.headings = {}
  M.line_to_heading = {}
  M.heading_to_line = {}
end

return M
