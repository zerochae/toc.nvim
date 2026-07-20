local config = require "toc.config"
local effects = require "toc.effects"
local state = require "toc.state"
local render = require "toc.render"

-- Two-way cursor sync between the TOC and the source window.
local M = {}

---@return boolean
local function source_win_valid()
  return state.src_win ~= nil and vim.api.nvim_win_is_valid(state.src_win)
end
M.source_win_valid = source_win_valid

---Display line of the first entry (below the title/blank), or nil.
---@return integer|nil
local function first_entry_line()
  return state.heading_to_line[1]
end

---Move the TOC cursor to the display line for entry `i` and mark it active.
---@param i integer
function M.focus_line(i)
  local lnum = state.heading_to_line[i]
  if lnum and state.is_open() then
    state.syncing = true
    pcall(vim.api.nvim_win_set_cursor, state.toc_win, { lnum, 0 })
    state.syncing = false
    render.set_active(i)
  end
end

---Scroll the source window to entry `idx` and flash the beacon.
---@param idx integer
local function scroll_source_to(idx)
  local heading = state.headings[idx]
  pcall(vim.api.nvim_win_call, state.src_win, function()
    vim.api.nvim_win_set_cursor(0, { heading.lnum, 0 })
    vim.cmd "normal! zz"
  end)
  render.set_active(idx)
  effects.beacon(state.src_buf, heading.lnum)
end

---Jump the source window to the entry under the TOC cursor.
---@param stay boolean keep focus in the TOC window
function M.jump(stay)
  if not state.is_open() or not source_win_valid() then
    return
  end
  local idx = state.line_to_heading[vim.api.nvim_win_get_cursor(state.toc_win)[1]]
  if not idx then
    return
  end

  vim.api.nvim_set_current_win(state.src_win)
  scroll_source_to(idx)

  if config.options.close_on_select then
    require("toc.view").close()
  elseif stay then
    vim.api.nvim_set_current_win(state.toc_win)
  end
end

---Follow: TOC cursor movement drives the source cursor (vertical-only).
function M.on_toc_move()
  if state.syncing then
    return
  end
  -- Keep the cursor at column 0 and out of the title/blank rows above entry 1.
  local pos = vim.api.nvim_win_get_cursor(state.toc_win)
  local row, col = pos[1], pos[2]
  local first = first_entry_line()
  if first and row < first then
    row = first
  end
  if row ~= pos[1] or col ~= 0 then
    state.syncing = true
    pcall(vim.api.nvim_win_set_cursor, state.toc_win, { row, 0 })
    state.syncing = false
  end
  if not config.options.follow_cursor or not source_win_valid() then
    return
  end
  local idx = state.line_to_heading[row]
  if idx then
    scroll_source_to(idx)
  end
end

---Reverse follow: source cursor movement marks the active entry.
function M.on_src_move()
  if state.syncing or not config.options.follow_source or not state.is_open() or not source_win_valid() then
    return
  end
  local cur = vim.api.nvim_win_get_cursor(state.src_win)[1]
  local active
  for i, h in ipairs(state.headings) do
    if h.lnum <= cur then
      if state.heading_to_line[i] then
        active = i
      end
    else
      break
    end
  end
  if active then
    M.focus_line(active)
  end
end

---Move the TOC cursor by `delta` entries (the CursorMoved autocmd follows).
---@param delta integer
---@param fallback integer starting index when the cursor isn't on an entry
function M.step(delta, fallback)
  local idx = state.line_to_heading[vim.api.nvim_win_get_cursor(state.toc_win)[1]]
  M.focus_line(math.max(1, math.min((idx or fallback) + delta, #state.headings)))
end

return M
