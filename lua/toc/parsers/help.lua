local config = require "toc.config"

local M = {}

-- Lines whose only non-space content is >= 3 of `ch` are Vim help section rules.
---@param line string
---@param ch string
---@return boolean
local function is_rule(line, ch)
  return line:match("^" .. ch .. "+%s*$") ~= nil and #line:gsub("%s", "") >= 3
end

-- Strip inline/trailing *tags* and surrounding whitespace from a title.
---@param s string
---@return string
local function clean(s)
  s = s:gsub("%*[^%s*]+%*", "")
  s = s:gsub("^%s+", "")
  s = s:gsub("%s+$", "")
  return s
end

local CALLOUTS = { note = true, warning = true, tip = true, caution = true, deprecated = true }

---Parse a Vim help buffer into typed entries (unsorted).
---  `===` / `---` rules  -> level 1 / 2 section headings (title on the next line)
---  `Foo ~`              -> subheading, one level under the current section
---  `> ... <`            -> code block
---  `Note:` / `WARNING:` -> callout
---  `*tag*`              -> anchor (link)
---@param bufnr integer
---@return TocEntry[]
function M.parse(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local el = config.options.elements
  local entries = {}

  local function on(kind)
    return el[kind] ~= nil and el[kind].enable
  end
  local function add(entry)
    entry.ord = #entries + 1
    entries[#entries + 1] = entry
  end

  local section = 0 -- level of the current === / --- section
  local head = 0 -- level of the most recent heading (section or ~)
  local expect -- a rule was seen; the next non-blank line is its title
  local in_code = false

  local function scan(i, line)
    -- Inside a `>` block: an unindented line (or a `<`) ends it.
    if in_code then
      if line:match "^<" then
        in_code = false
        return
      elseif line == "" or line:match "^%s" then
        return
      end
      in_code = false -- unindented line: block ended, process it below
    end

    if expect then
      if line:match "%S" then
        if not is_rule(line, "=") and not is_rule(line, "%-") then
          local text = clean(line)
          if text ~= "" and on("heading") then
            section, head = expect, expect
            add { lnum = i, level = expect, kind = "heading", text = text }
          end
        end
        expect = nil
      end
      return
    end

    if is_rule(line, "=") then
      expect = 1
      return
    elseif is_rule(line, "%-") then
      expect = 2
      return
    end

    local sub = line:match "^(%S.-)%s*~%s*$"
    if sub then
      head = math.max(section, 1) + 1
      if on("heading") then
        add { lnum = i, level = head, kind = "heading", text = clean(sub) }
      end
      return
    end

    local word, rest = line:match "^%s*([%a]+):%s*(.*)$"
    if word and CALLOUTS[word:lower()] then
      if on("callout") then
        add {
          lnum = i,
          level = head + 1,
          kind = "callout",
          text = rest ~= "" and clean(rest) or word,
          label = word:lower(),
        }
      end
      return
    end

    -- A line ending in ">" or ">{lang}" (e.g. ">lua") opens a code block.
    local lang = line:match "%s>([%w_]*)%s*$" or line:match "^>([%w_]*)%s*$"
    if lang then
      if on("code") then
        add { lnum = i, level = head + 1, kind = "code", text = lang ~= "" and lang or "code" }
      end
      in_code = true
      return
    end

    if on("link") then
      for tag in line:gmatch "%*([^%s*|]+)%*" do
        add { lnum = i, level = head + 1, kind = "link", text = tag }
      end
    end
  end

  for i, line in ipairs(lines) do
    scan(i, line)
  end
  return entries
end

return M
