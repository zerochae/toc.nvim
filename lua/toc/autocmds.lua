local config = require "toc.config"
local state = require "toc.state"
local render = require "toc.render"
local parser = require "toc.parser"
local cursor = require "toc.cursor"

-- Buffer-local keymaps and the autocmds that keep the TOC in sync.
local M = {}

local refresh_timer

---Refresh after `refresh_debounce` ms of quiet (0 = immediate). Saving is
---always immediate (a separate BufWritePost autocmd).
local function debounced_refresh()
  local ms = config.options.refresh_debounce or 0
  if ms <= 0 then
    require("toc.view").refresh()
    return
  end
  refresh_timer = refresh_timer or vim.uv.new_timer()
  if not refresh_timer then
    require("toc.view").refresh()
    return
  end
  refresh_timer:stop()
  refresh_timer:start(ms, 0, vim.schedule_wrap(function()
    require("toc.view").refresh()
  end))
end

local function stop_refresh_timer()
  if refresh_timer then
    refresh_timer:stop()
    refresh_timer:close()
    refresh_timer = nil
  end
end

---Is `buf` a real file whose filetype the TOC indexes?
---@param buf integer
---@return boolean
local function is_toc_filetype(buf)
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
  map(km.jump, function()
    cursor.jump(false)
  end)
  map(km.jump_stay, function()
    cursor.jump(true)
  end)
  map(km.close, function()
    require("toc.view").close()
  end)
  map(km.refresh, function()
    require("toc.view").refresh()
  end)
  map(km.next, function()
    cursor.step(1, 0)
  end)
  map(km.prev, function()
    cursor.step(-1, 2)
  end)
end

local function set_source_autocmds()
  vim.api.nvim_clear_autocmds { group = state.augroup }

  vim.api.nvim_create_autocmd("CursorMoved", {
    group = state.augroup,
    buffer = state.toc_buf,
    callback = cursor.on_toc_move,
  })

  if state.src_buf then
    vim.api.nvim_create_autocmd("CursorMoved", {
      group = state.augroup,
      buffer = state.src_buf,
      callback = cursor.on_src_move,
    })

    -- Saving always re-syncs the TOC, regardless of the live-update setting.
    vim.api.nvim_create_autocmd("BufWritePost", {
      group = state.augroup,
      buffer = state.src_buf,
      callback = function()
        require("toc.view").refresh()
      end,
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
        require("toc.view").close()
      end
    end,
  })
end
M.set_source_autocmds = set_source_autocmds

---Point the TOC at a different source buffer/window and re-render.
---@param win integer
---@param buf integer
local function rebind_source(win, buf)
  state.src_win = win
  state.src_buf = buf
  state.headings = parser.parse(buf)
  pcall(vim.api.nvim_buf_set_name, state.toc_buf, "toc://" .. buf)
  render.draw()
  set_source_autocmds()
end

---Watch for the source window switching to another buffer.
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
      if is_toc_filetype(args.buf) then
        rebind_source(win, args.buf)
      elseif config.options.auto_close and vim.bo[args.buf].buftype == "" and vim.bo[args.buf].filetype ~= "" then
        -- Switched to a real file that isn't indexed: hide the TOC.
        require("toc.view").close()
      end
    end,
  })
end

---Register all keymaps and autocmds for the current TOC/source buffers.
function M.attach()
  set_keymaps()
  set_source_autocmds()
  set_switch_autocmd()
end

---Tear down timers and autocmd groups.
function M.detach()
  stop_refresh_timer()
  vim.api.nvim_clear_autocmds { group = state.augroup }
  vim.api.nvim_clear_autocmds { group = state.augroup_switch }
end

return M
