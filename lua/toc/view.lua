local config = require "toc.config"
local parser = require "toc.parser"
local state = require "toc.state"
local render = require "toc.render"
local autocmds = require "toc.autocmds"
local cursor = require "toc.cursor"

-- Controller: window lifecycle and the public API. Rendering lives in
-- render/layout, cursor sync in cursor, and event wiring in autocmds.
local M = {}

M.is_open = state.is_open
M.jump = cursor.jump

---@return table
function M.state()
  return state
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
  autocmds.attach()

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
  autocmds.detach()
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
