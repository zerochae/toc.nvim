local config = require "toc.config"

local M = {}

local ns = vim.api.nvim_create_namespace "toc.nvim.beacon"
local active = { buf = nil, mark = nil, hl = "TocBeaconFade" }

---@param n integer|nil packed 0xRRGGBB colour
---@return integer[]|nil {r, g, b}
local function unpack_rgb(n)
  if type(n) ~= "number" then
    return nil
  end
  return { math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256 }
end

---@param name string
---@param key string "fg"|"bg"
---@return integer[]|nil
local function hl_color(name, key)
  local ok, def = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
  if not ok or not def then
    return nil
  end
  return unpack_rgb(def[key])
end

---@param a integer[]
---@param b integer[]
---@param t number 0..1
---@return string hex colour
local function blend(a, b, t)
  local function mix(i)
    return math.floor(a[i] + (b[i] - a[i]) * t + 0.5)
  end
  return string.format("#%02x%02x%02x", mix(1), mix(2), mix(3))
end

---Clear any in-flight beacon.
local function clear()
  if active.buf and active.mark and vim.api.nvim_buf_is_valid(active.buf) then
    pcall(vim.api.nvim_buf_del_extmark, active.buf, ns, active.mark)
  end
  active.buf, active.mark = nil, nil
end

---Flash a fading line highlight at `lnum` (1-based) in `buf`.
---@param buf integer
---@param lnum integer
function M.beacon(buf, lnum)
  local opts = config.options.effects.beacon
  if not opts.enable or not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  clear()

  local from = hl_color(opts.hl, "bg") or hl_color("Search", "bg") or { 240, 200, 90 }
  local to = hl_color("Normal", "bg") or { 30, 30, 40 }
  local steps = math.max(opts.fade_steps, 1)
  local step_ms = math.max(math.floor(opts.duration / steps), 10)

  vim.api.nvim_set_hl(0, active.hl, { bg = blend(from, to, 0) })
  local ok, mark = pcall(vim.api.nvim_buf_set_extmark, buf, ns, lnum - 1, 0, {
    line_hl_group = active.hl,
    hl_eol = true,
    priority = 200,
  })
  if not ok then
    return
  end
  active.buf, active.mark = buf, mark

  local frame = 0
  local function tick()
    frame = frame + 1
    if frame > steps or active.mark ~= mark or not vim.api.nvim_buf_is_valid(buf) then
      if active.mark == mark then
        clear()
      end
      return
    end
    vim.api.nvim_set_hl(0, active.hl, { bg = blend(from, to, frame / steps) })
    vim.defer_fn(tick, step_ms)
  end
  vim.defer_fn(tick, step_ms)
end

return M
