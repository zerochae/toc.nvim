local Parser = require "toc.parsers.base"

-- reStructuredText: sections are titles underlined (optionally overlined) by a
-- run of a punctuation char. The character does not fix the level -- the order
-- in which each (overline?, char) combination first appears does.
---@class Rst : Parser
---@field levels table<string, integer> adornment key -> assigned level
---@field next_level integer levels handed out so far
---@field skip integer lines already consumed (an underline row)
local Rst = setmetatable({}, { __index = Parser })
Rst.__index = Rst

---@param bufnr integer
---@return Rst
function Rst.new(bufnr)
  local self = Parser.new(bufnr) --[[@as Rst]]
  self.levels = {}
  self.next_level = 0
  self.skip = 0
  return setmetatable(self, Rst)
end

-- A line that is a single punctuation char repeated (>= 2), nothing else.
-- `:` `<` `>` are excluded: they collide with roles / literal blocks.
---@param line string|nil
---@return string|nil char
local function adorn_char(line)
  if not line then
    return nil
  end
  local body = line:gsub("%s+$", "")
  local c = body:match "^([=%-~^\"'%*%+#%._])"
  -- Lua patterns can't quantify a back-reference, so compare against a run.
  if c and #body >= 2 and body == string.rep(c, #body) then
    return c
  end
  return nil
end

---@param text string
---@return string
local function clean(text)
  text = text:gsub("^%s+", ""):gsub("%s+$", "")
  text = text:gsub("``([^`]*)``", "%1")
  text = text:gsub("`([^`<]-)%s*<[^>]*>`_+", "%1")
  text = text:gsub("`([^`]*)`_*", "%1")
  text = text:gsub("%*+", "")
  return text
end

---@param key string
---@return integer
function Rst:level_for(key)
  if not self.levels[key] then
    self.next_level = self.next_level + 1
    self.levels[key] = math.min(self.next_level, 6)
  end
  return self.levels[key]
end

---@param i integer
---@param line string
function Rst:scan(i, line)
  if i <= self.skip then
    return
  end

  -- Code via a directive: `.. code-block:: lua` or `.. code:: lua`.
  local lang = line:match "^%s*%.%.%s+[Cc]ode%-?[Bb]?[Ll]?[Oo]?[Cc]?[Kk]?::%s*(%S*)"
  if lang ~= nil then
    if self:enabled "code" then
      self:add { lnum = i, level = self:child_level(), kind = "code", text = lang ~= "" and lang or "code" }
    end
    return
  end

  -- Section title: this line is text, the next line is an underline adornment.
  local under = adorn_char(self.lines[i + 1])
  if under and line:match "%S" and not adorn_char(line) then
    local over = adorn_char(self.lines[i - 1]) == under
    local lvl = self:level_for((over and "o" or "u") .. under)
    self.head_level = lvl
    if self:enabled "heading" then
      local text = clean(line)
      self:add { lnum = i, level = lvl, kind = "heading", text = text ~= "" and text or "(untitled)" }
    end
    self.skip = i + 1
    return
  end

  -- Inline links: `text <url>`_ (or anonymous `text <url>`__).
  if self:enabled "link" then
    for txt in line:gmatch "`([^`<]-)%s*<[^>]+>`__?" do
      local text = clean(txt)
      if text ~= "" then
        self:add { lnum = i, level = self:child_level(), kind = "link", text = text }
      end
    end
  end
end

---Scan an rST buffer line-by-line, emitting typed entries (unsorted).
---@return TocEntry[]
function Rst:parse()
  self.lines = self:lines()
  for i, line in ipairs(self.lines) do
    self:scan(i, line)
  end
  return self.entries
end

return Rst
