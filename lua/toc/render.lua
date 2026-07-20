local config = require "toc.config"
local state = require "toc.state"
local layout = require "toc.layout"

-- Buffer/window side effects: writes the lines and marks that layout computes,
-- sizes an "auto" panel, and draws the active-entry marker.
local M = {}

---Draw the active-entry marker (sign + line highlight) on entry `i`.
---@param i integer|nil
function M.set_active(i)
  if not (state.toc_buf and vim.api.nvim_buf_is_valid(state.toc_buf)) then
    return
  end
  vim.api.nvim_buf_clear_namespace(state.toc_buf, state.ns_active, 0, -1)
  local lnum = i and state.heading_to_line[i]
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
  pcall(vim.api.nvim_buf_set_extmark, state.toc_buf, state.ns_active, lnum - 1, 0, mopts)
end

---Render the current entries into the TOC buffer.
function M.draw()
  if not (state.toc_buf and vim.api.nvim_buf_is_valid(state.toc_buf)) then
    return
  end

  local lines, marks, line_to_entry, entry_to_line = layout.build(state.headings)
  state.line_to_heading = line_to_entry
  state.heading_to_line = entry_to_line

  vim.bo[state.toc_buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.toc_buf, 0, -1, false, lines)
  vim.bo[state.toc_buf].modifiable = false

  vim.api.nvim_buf_clear_namespace(state.toc_buf, state.ns, 0, -1)
  vim.api.nvim_buf_clear_namespace(state.toc_buf, state.ns_active, 0, -1)
  for _, mark in ipairs(marks) do
    pcall(vim.api.nvim_buf_set_extmark, state.toc_buf, state.ns, mark.line, mark.col, {
      end_col = mark.end_col,
      hl_group = mark.hl,
    })
  end

  -- Size an "auto" panel to the widest line plus padding (capped at width_max).
  local opts = config.options
  if opts.width == "auto" and state.is_open() then
    local maxw = 0
    for _, l in ipairs(lines) do
      maxw = math.max(maxw, vim.fn.strdisplaywidth(l))
    end
    local w = math.min(maxw + layout.sign_width() + (opts.padding or 0), opts.width_max or 60)
    pcall(vim.api.nvim_win_set_width, state.toc_win, math.max(w, 8))
  end

  if state.is_open() then
    local cur = vim.api.nvim_win_get_cursor(state.toc_win)[1]
    M.set_active(state.line_to_heading[cur])
  end
end

return M
