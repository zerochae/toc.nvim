local config = require "toc.config"

local M = {}

---A line made only of `ch` (>= 3), the section rules in Vim help files.
---@param line string
---@param ch string
---@return boolean
local function is_rule(line, ch)
  return line:match("^" .. ch .. "+%s*$") ~= nil and #line:gsub("%s", "") >= 3
end

---Strip trailing/inline *tags* and surrounding whitespace from a title.
---@param s string
---@return string
local function clean(s)
  s = s:gsub("%*[^*%s]+%*", "")
  s = s:gsub("^%s+", "")
  s = s:gsub("%s+$", "")
  return s
end

---Parse a Vim help buffer: `===` rules start level-1 sections, `---` level-2.
---The heading is the next non-blank line; its `*tag*` is dropped.
---@param bufnr integer
---@return TocEntry[]
function M.parse(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local heading = config.options.elements.heading
  if heading ~= nil and heading.enable == false then
    return {}
  end

  local entries = {}
  for i, line in ipairs(lines) do
    local level
    if is_rule(line, "=") then
      level = 1
    elseif is_rule(line, "%-") then
      level = 2
    end
    if level then
      local j = i + 1
      while lines[j] and lines[j]:match "^%s*$" do
        j = j + 1
      end
      local title = lines[j]
      if title and not is_rule(title, "=") and not is_rule(title, "%-") then
        local text = clean(title)
        if text ~= "" then
          entries[#entries + 1] =
            { lnum = j, level = level, kind = "heading", text = text, ord = #entries + 1 }
        end
      end
    end
  end
  return entries
end

return M
