local config = require "toc.config"
local parser = require "toc.parser"
local layout = require "toc.layout"
local effects = require "toc.effects"

-- The TOC panel as one object. It owns the window/buffer state, draws what
-- layout computes, keeps the cursor in sync both ways, and wires its own
-- autocmds/keymaps. Folding these together removes the load-order cycle that
-- separate view/cursor/render/autocmds modules had to break with lazy requires.

-- Process-global resources (namespaces and augroups are global regardless).
local ns = vim.api.nvim_create_namespace "toc.nvim"
local ns_active = vim.api.nvim_create_namespace "toc.nvim.active"
local augroup = vim.api.nvim_create_augroup("toc.nvim", { clear = true })
local augroup_switch = vim.api.nvim_create_augroup("toc.nvim.switch", { clear = true })

-- Highlight groups created on demand for fg-coloured marks (code language icons).
local fg_hl_cache = {}
local function ensure_fg_hl(fg)
  local hl = "TocLang_" .. fg:gsub("[^%x]", "")
  if not fg_hl_cache[hl] then
    pcall(vim.api.nvim_set_hl, 0, hl, { fg = fg, default = true })
    fg_hl_cache[hl] = true
  end
  return hl
end

---@param buf integer
---@return boolean
local function is_toc_filetype(buf)
  if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= "" then
    return false
  end
  return vim.tbl_contains(config.options.filetypes, vim.bo[buf].filetype)
end

---@class View
---@field src_buf integer|nil source buffer
---@field src_win integer|nil source window
---@field toc_buf integer|nil toc scratch buffer
---@field toc_win integer|nil toc window
---@field headings TocEntry[]
---@field line_to_heading table<integer, integer> toc display line -> entry index
---@field heading_to_line table<integer, integer> entry index -> toc display line
---@field syncing boolean guard against follow feedback loops
local View = {}
View.__index = View

local current ---@type View|nil the single live panel, nil when closed
local close_panel ---@type fun() forward declared; tears down and clears `current`
local refresh_timer

---@return View
function View.new()
  return setmetatable({
    headings = {},
    line_to_heading = {},
    heading_to_line = {},
    syncing = false,
  }, View)
end

---@return boolean
function View:is_open()
  return self.toc_win ~= nil and vim.api.nvim_win_is_valid(self.toc_win)
end

-- ── drawing (was render.lua) ────────────────────────────────────────────────

---Draw the active-entry marker (sign + line highlight) on entry `i`.
---@param i integer|nil
function View:set_active(i)
  if not (self.toc_buf and vim.api.nvim_buf_is_valid(self.toc_buf)) then
    return
  end
  vim.api.nvim_buf_clear_namespace(self.toc_buf, ns_active, 0, -1)
  local lnum = i and self.heading_to_line[i]
  if not lnum then
    return
  end
  local eff = config.options.effects
  local mopts = { priority = 150 }
  if eff.active_line.enable then
    mopts.line_hl_group = eff.active_line.hl
    mopts.hl_eol = true
  end
  if eff.active_sign.enable then
    mopts.sign_text = eff.active_sign.text
    mopts.sign_hl_group = eff.active_sign.hl
  end
  pcall(vim.api.nvim_buf_set_extmark, self.toc_buf, ns_active, lnum - 1, 0, mopts)
end

---Rebuild the buffer lines and marks, size an "auto" panel, mark the active row.
function View:draw()
  if not (self.toc_buf and vim.api.nvim_buf_is_valid(self.toc_buf)) then
    return
  end

  local lines, marks, line_to_entry, entry_to_line = layout.build(self.headings)
  self.line_to_heading = line_to_entry
  self.heading_to_line = entry_to_line

  vim.bo[self.toc_buf].modifiable = true
  vim.api.nvim_buf_set_lines(self.toc_buf, 0, -1, false, lines)
  vim.bo[self.toc_buf].modifiable = false

  vim.api.nvim_buf_clear_namespace(self.toc_buf, ns, 0, -1)
  vim.api.nvim_buf_clear_namespace(self.toc_buf, ns_active, 0, -1)
  for _, mark in ipairs(marks) do
    pcall(vim.api.nvim_buf_set_extmark, self.toc_buf, ns, mark.line, mark.col, {
      end_col = mark.end_col,
      hl_group = mark.fg and ensure_fg_hl(mark.fg) or mark.hl,
    })
  end

  local opts = config.options
  if opts.width == "auto" and self:is_open() then
    local maxw = 0
    for _, l in ipairs(lines) do
      maxw = math.max(maxw, vim.fn.strdisplaywidth(l))
    end
    local w = math.min(maxw + layout.sign_width() + (opts.padding or 0), opts.width_max or 60)
    pcall(vim.api.nvim_win_set_width, self.toc_win, math.max(w, 8))
  end

  if self:is_open() then
    local cur = vim.api.nvim_win_get_cursor(self.toc_win)[1]
    self:set_active(self.line_to_heading[cur])
  end
end

-- ── two-way cursor sync (was cursor.lua) ────────────────────────────────────

---@return boolean
function View:source_win_valid()
  return self.src_win ~= nil and vim.api.nvim_win_is_valid(self.src_win)
end

---Move the TOC cursor to the display line for entry `i` and mark it active.
---@param i integer
function View:focus_line(i)
  local lnum = self.heading_to_line[i]
  if lnum and self:is_open() then
    self.syncing = true
    pcall(vim.api.nvim_win_set_cursor, self.toc_win, { lnum, 0 })
    self.syncing = false
    self:set_active(i)
  end
end

---Scroll the source window to entry `idx` and flash the beacon.
---@param idx integer
function View:scroll_source_to(idx)
  local heading = self.headings[idx]
  pcall(vim.api.nvim_win_call, self.src_win, function()
    vim.api.nvim_win_set_cursor(0, { heading.lnum, 0 })
    vim.cmd "normal! zz"
  end)
  self:set_active(idx)
  effects.beacon(self.src_buf, heading.lnum)
end

---Jump the source window to the entry under the TOC cursor.
---@param stay boolean keep focus in the TOC window
function View:jump(stay)
  if not self:is_open() or not self:source_win_valid() then
    return
  end
  local idx = self.line_to_heading[vim.api.nvim_win_get_cursor(self.toc_win)[1]]
  if not idx then
    return
  end

  vim.api.nvim_set_current_win(self.src_win)
  self:scroll_source_to(idx)

  if config.options.close_on_select then
    close_panel()
  elseif stay then
    vim.api.nvim_set_current_win(self.toc_win)
  end
end

---Follow: TOC cursor movement drives the source cursor (vertical-only).
function View:on_toc_move()
  if self.syncing then
    return
  end
  -- Keep the cursor at column 0 and out of the title/blank rows above entry 1.
  local pos = vim.api.nvim_win_get_cursor(self.toc_win)
  local row, col = pos[1], pos[2]
  local first = self.heading_to_line[1]
  if first and row < first then
    row = first
  end
  if row ~= pos[1] or col ~= 0 then
    self.syncing = true
    pcall(vim.api.nvim_win_set_cursor, self.toc_win, { row, 0 })
    self.syncing = false
  end
  if not config.options.follow_cursor or not self:source_win_valid() then
    return
  end
  local idx = self.line_to_heading[row]
  if idx then
    self:scroll_source_to(idx)
  end
end

---Reverse follow: source cursor movement marks the active entry.
function View:on_src_move()
  if self.syncing or not config.options.follow_source or not self:is_open() or not self:source_win_valid() then
    return
  end
  local cur = vim.api.nvim_win_get_cursor(self.src_win)[1]
  -- headings are sorted by lnum; binary-search the last entry at or above the
  -- cursor, then step back to the nearest displayed one.
  local lo, hi, idx = 1, #self.headings, nil
  while lo <= hi do
    local mid = math.floor((lo + hi) / 2)
    if self.headings[mid].lnum <= cur then
      idx = mid
      lo = mid + 1
    else
      hi = mid - 1
    end
  end
  local active
  while idx do
    if self.heading_to_line[idx] then
      active = idx
      break
    end
    idx = idx - 1
  end
  if active then
    self:focus_line(active)
  end
end

---Move the TOC cursor by `delta` entries (the CursorMoved autocmd follows).
---@param delta integer
---@param fallback integer starting index when the cursor isn't on an entry
function View:step(delta, fallback)
  local idx = self.line_to_heading[vim.api.nvim_win_get_cursor(self.toc_win)[1]]
  self:focus_line(math.max(1, math.min((idx or fallback) + delta, #self.headings)))
end

-- ── events (was autocmds.lua) ───────────────────────────────────────────────

local function stop_refresh_timer()
  if refresh_timer then
    refresh_timer:stop()
    refresh_timer:close()
    refresh_timer = nil
  end
end

---Refresh after `refresh_debounce` ms of quiet (0 = immediate).
function View:debounced_refresh()
  local ms = config.options.refresh_debounce or 0
  if ms <= 0 then
    self:refresh()
    return
  end
  refresh_timer = refresh_timer or vim.uv.new_timer()
  if not refresh_timer then
    self:refresh()
    return
  end
  refresh_timer:stop()
  refresh_timer:start(
    ms,
    0,
    vim.schedule_wrap(function()
      self:refresh()
    end)
  )
end

function View:set_keymaps()
  local km = config.options.keymaps
  local function map(lhs, fn)
    if lhs then
      vim.keymap.set("n", lhs, fn, { buffer = self.toc_buf, nowait = true, silent = true })
    end
  end
  map(km.jump, function()
    self:jump(false)
  end)
  map(km.jump_stay, function()
    self:jump(true)
  end)
  map(km.close, function()
    close_panel()
  end)
  map(km.refresh, function()
    self:refresh()
  end)
  map(km.next, function()
    self:step(1, 0)
  end)
  map(km.prev, function()
    self:step(-1, 2)
  end)
end

function View:set_source_autocmds()
  vim.api.nvim_clear_autocmds { group = augroup }

  vim.api.nvim_create_autocmd("CursorMoved", {
    group = augroup,
    buffer = self.toc_buf,
    callback = function()
      self:on_toc_move()
    end,
  })

  if self.src_buf then
    vim.api.nvim_create_autocmd("CursorMoved", {
      group = augroup,
      buffer = self.src_buf,
      callback = function()
        self:on_src_move()
      end,
    })

    -- Saving always re-syncs the TOC, regardless of the live-update setting.
    vim.api.nvim_create_autocmd("BufWritePost", {
      group = augroup,
      buffer = self.src_buf,
      callback = function()
        self:refresh()
      end,
    })

    if config.options.auto_refresh then
      vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
        group = augroup,
        buffer = self.src_buf,
        callback = function()
          self:debounced_refresh()
        end,
      })
    end
  end

  vim.api.nvim_create_autocmd("WinClosed", {
    group = augroup,
    callback = function(args)
      if tonumber(args.match) == self.toc_win then
        close_panel()
      end
    end,
  })
end

---Point the TOC at a different source buffer/window and re-render.
---@param win integer
---@param buf integer
function View:rebind_source(win, buf)
  self.src_win = win
  self.src_buf = buf
  self.headings = parser.parse(buf)
  pcall(vim.api.nvim_buf_set_name, self.toc_buf, "toc://" .. buf)
  self:draw()
  self:set_source_autocmds()
end

---Watch for the source window switching to another buffer.
function View:set_switch_autocmd()
  vim.api.nvim_clear_autocmds { group = augroup_switch }
  vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter", "FileType" }, {
    group = augroup_switch,
    callback = function(args)
      if not self:is_open() then
        return
      end
      local win = vim.api.nvim_get_current_win()
      if win == self.toc_win or args.buf == self.toc_buf or args.buf == self.src_buf then
        return
      end
      if is_toc_filetype(args.buf) then
        self:rebind_source(win, args.buf)
      elseif config.options.auto_close and vim.bo[args.buf].buftype == "" and vim.bo[args.buf].filetype ~= "" then
        -- Switched to a real file that isn't indexed: hide the TOC.
        close_panel()
      end
    end,
  })
end

function View:attach()
  self:set_keymaps()
  self:set_source_autocmds()
  self:set_switch_autocmd()
end

function View:detach()
  stop_refresh_timer()
  vim.api.nvim_clear_autocmds { group = augroup }
  vim.api.nvim_clear_autocmds { group = augroup_switch }
end

-- ── window lifecycle (was view.lua) ─────────────────────────────────────────

function View:apply_window_options()
  local win = self.toc_win
  if not win then
    return
  end
  for opt, value in pairs(config.options.window) do
    pcall(function()
      vim.wo[win][opt] = value
    end)
  end
  -- A numeric width is fixed here; "auto" is sized by draw to fit content.
  if type(config.options.width) == "number" then
    vim.api.nvim_win_set_width(win, config.options.width)
  end
end

function View:create_window()
  self.src_win = vim.api.nvim_get_current_win()
  self.src_buf = vim.api.nvim_get_current_buf()
  self.headings = parser.parse(self.src_buf)

  self.toc_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[self.toc_buf].bufhidden = "wipe"
  vim.bo[self.toc_buf].filetype = "toc"
  vim.bo[self.toc_buf].buftype = "nofile"
  vim.api.nvim_buf_set_name(self.toc_buf, "toc://" .. self.src_buf)

  local side = config.options.position == "left" and "topleft" or "botright"
  vim.cmd(side .. " vsplit")
  self.toc_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(self.toc_win, self.toc_buf)

  self:apply_window_options()
  self:draw()
  self:attach()

  -- Start on the first entry, not the title line.
  if self.heading_to_line[1] then
    pcall(vim.api.nvim_win_set_cursor, self.toc_win, { self.heading_to_line[1], 0 })
  end

  if not config.options.focus_on_open then
    vim.api.nvim_set_current_win(self.src_win)
  end
end

---Re-parse the source buffer and re-render without losing the window.
function View:refresh()
  if not self:is_open() or not (self.src_buf and vim.api.nvim_buf_is_valid(self.src_buf)) then
    return
  end
  self.headings = parser.parse(self.src_buf)
  self:draw()
end

function View:teardown()
  self:detach()
  if self.toc_win and vim.api.nvim_win_is_valid(self.toc_win) then
    pcall(vim.api.nvim_win_close, self.toc_win, true)
  end
end

close_panel = function()
  if current then
    current:teardown()
    current = nil
  end
end

-- ── public API: the single-panel facade ─────────────────────────────────────

local M = {}

function M.open()
  if current and current:is_open() then
    vim.api.nvim_set_current_win(current.toc_win)
    return
  end
  current = View.new()
  current:create_window()
end

function M.close()
  close_panel()
end

function M.toggle()
  if M.is_open() then
    close_panel()
  else
    M.open()
  end
end

function M.refresh()
  if current then
    current:refresh()
  end
end

---@return boolean
function M.is_open()
  return current ~= nil and current:is_open()
end

---Jump the source window to the entry under the TOC cursor.
---@param stay boolean keep focus in the TOC window
function M.jump(stay)
  if current then
    current:jump(stay)
  end
end

---The live panel (its window/buffer/heading state), or nil when closed.
---@return View|nil
function M.state()
  return current
end

return M
