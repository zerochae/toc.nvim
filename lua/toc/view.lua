local config = require "toc.config"
local effects = require "toc.effects"
local parser = require "toc.parser"
local state = require "toc.state"
local render = require "toc.render"

local M = {}

M.is_open = state.is_open

---@return table
function M.state()
  return state
end

local refresh_timer

---Refresh after `refresh_debounce` ms of quiet (0 = immediate).
local function debounced_refresh()
  local ms = config.options.refresh_debounce or 0
  if ms <= 0 then
    M.refresh()
    return
  end
  refresh_timer = refresh_timer or vim.uv.new_timer()
  if not refresh_timer then
    M.refresh()
    return
  end
  refresh_timer:stop()
  refresh_timer:start(ms, 0, vim.schedule_wrap(M.refresh))
end

local function stop_refresh_timer()
  if refresh_timer then
    refresh_timer:stop()
    refresh_timer:close()
    refresh_timer = nil
  end
end

---Move the TOC cursor to the display line for entry `i` and mark it active.
---@param i integer
local function focus_line(i)
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

---@return boolean
local function source_win_valid()
  return state.src_win ~= nil and vim.api.nvim_win_is_valid(state.src_win)
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
    M.close()
  elseif stay then
    vim.api.nvim_set_current_win(state.toc_win)
  end
end

---Display line of the first entry (below the title/blank), or nil.
---@return integer|nil
local function first_entry_line()
  return state.heading_to_line[1]
end

---Follow: TOC cursor movement drives the source cursor.
local function on_toc_cursor()
  if state.syncing then
    return
  end
  -- Vertical-only: keep the cursor at column 0 and out of the title/blank rows.
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
local function on_src_cursor()
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
    focus_line(active)
  end
end

---@param buf integer
---@return boolean
local function is_markdown(buf)
  if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= "" then
    return false
  end
  return vim.tbl_contains(config.options.filetypes, vim.bo[buf].filetype)
end

local function set_keymaps()
  local km = config.options.keymaps
  local function map(lhs, fn)
    if lhs then
      vim.keymap.set("n", lhs, fn, { buffer = state.toc_buf, nowait = true, silent = true })
    end
  end
  -- Move the TOC cursor; the CursorMoved autocmd handles the source follow.
  local function step(delta, fallback)
    local idx = state.line_to_heading[vim.api.nvim_win_get_cursor(state.toc_win)[1]]
    focus_line(math.max(1, math.min((idx or fallback) + delta, #state.headings)))
  end
  map(km.jump, function()
    M.jump(false)
  end)
  map(km.jump_stay, function()
    M.jump(true)
  end)
  map(km.close, M.close)
  map(km.refresh, M.refresh)
  map(km.next, function()
    step(1, 0)
  end)
  map(km.prev, function()
    step(-1, 2)
  end)
end

local function set_autocmds()
  vim.api.nvim_clear_autocmds { group = state.augroup }

  vim.api.nvim_create_autocmd("CursorMoved", {
    group = state.augroup,
    buffer = state.toc_buf,
    callback = on_toc_cursor,
  })

  if state.src_buf then
    vim.api.nvim_create_autocmd("CursorMoved", {
      group = state.augroup,
      buffer = state.src_buf,
      callback = on_src_cursor,
    })

    -- Saving always re-syncs the TOC, regardless of the live-update setting.
    vim.api.nvim_create_autocmd("BufWritePost", {
      group = state.augroup,
      buffer = state.src_buf,
      callback = M.refresh,
    })

    if config.options.auto_refresh then
      vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
        group = state.augroup,
        buffer = state.src_buf,
        callback = debounced_refresh,
      })
    end
  end

  vim.api.nvim_create_autocmd("WinClosed", {
    group = state.augroup,
    callback = function(args)
      if tonumber(args.match) == state.toc_win then
        M.close()
      end
    end,
  })
end

---Point the TOC at a different source buffer/window and re-render.
---@param win integer
---@param buf integer
local function rebind_source(win, buf)
  state.src_win = win
  state.src_buf = buf
  state.headings = parser.parse(buf)
  pcall(vim.api.nvim_buf_set_name, state.toc_buf, "toc://" .. buf)
  render.draw()
  set_autocmds()
end

---Watch for the source window switching to another markdown buffer.
local function set_switch_autocmd()
  vim.api.nvim_clear_autocmds { group = state.augroup_switch }
  vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter", "FileType" }, {
    group = state.augroup_switch,
    callback = function(args)
      if not state.is_open() then
        return
      end
      local win = vim.api.nvim_get_current_win()
      if win == state.toc_win or args.buf == state.toc_buf or args.buf == state.src_buf then
        return
      end
      if is_markdown(args.buf) then
        rebind_source(win, args.buf)
      elseif config.options.auto_close and vim.bo[args.buf].buftype == "" and vim.bo[args.buf].filetype ~= "" then
        -- Switched to a real file that isn't markdown: hide the TOC.
        M.close()
      end
    end,
  })
end

local function apply_window_options()
  local win = state.toc_win
  if not win then
    return
  end
  for opt, value in pairs(config.options.window) do
    pcall(function()
      vim.wo[win][opt] = value
    end)
  end
  -- A numeric width is fixed here; "auto" is sized by render.draw to fit content.
  if type(config.options.width) == "number" then
    vim.api.nvim_win_set_width(win, config.options.width)
  end
end

local function create_window()
  state.src_win = vim.api.nvim_get_current_win()
  state.src_buf = vim.api.nvim_get_current_buf()
  state.headings = parser.parse(state.src_buf)

  state.toc_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[state.toc_buf].bufhidden = "wipe"
  vim.bo[state.toc_buf].filetype = "toc"
  vim.bo[state.toc_buf].buftype = "nofile"
  vim.api.nvim_buf_set_name(state.toc_buf, "toc://" .. state.src_buf)

  local side = config.options.position == "left" and "topleft" or "botright"
  vim.cmd(side .. " vsplit")
  state.toc_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(state.toc_win, state.toc_buf)

  apply_window_options()
  render.draw()
  set_keymaps()
  set_autocmds()
  set_switch_autocmd()

  -- Start on the first entry, not the title line.
  if state.heading_to_line[1] then
    pcall(vim.api.nvim_win_set_cursor, state.toc_win, { state.heading_to_line[1], 0 })
  end

  if not config.options.focus_on_open then
    vim.api.nvim_set_current_win(state.src_win)
  end
end

function M.open()
  if state.is_open() then
    vim.api.nvim_set_current_win(state.toc_win)
    return
  end
  create_window()
end

function M.close()
  stop_refresh_timer()
  vim.api.nvim_clear_autocmds { group = state.augroup }
  vim.api.nvim_clear_autocmds { group = state.augroup_switch }
  if state.toc_win and vim.api.nvim_win_is_valid(state.toc_win) then
    pcall(vim.api.nvim_win_close, state.toc_win, true)
  end
  state.reset()
end

function M.toggle()
  if state.is_open() then
    M.close()
  else
    M.open()
  end
end

---Re-parse the source buffer and re-render without losing the window.
function M.refresh()
  if not state.is_open() or not (state.src_buf and vim.api.nvim_buf_is_valid(state.src_buf)) then
    return
  end
  state.headings = parser.parse(state.src_buf)
  render.draw()
end

return M
