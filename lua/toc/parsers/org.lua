local Parser = require "toc.parsers.base"

---@class Org : Parser
---@field in_src boolean inside a #+BEGIN_SRC block
local Org = setmetatable({}, { __index = Parser })
Org.__index = Org

---@param bufnr integer
---@return Org
function Org.new(bufnr)
  local self = Parser.new(bufnr) --[[@as Org]]
  self.in_src = false
  return setmetatable(self, Org)
end

-- Common TODO-style keywords stripped from a heading's title.
local KEYWORDS = {
  TODO = true,
  DONE = true,
  NEXT = true,
  DOING = true,
  WAITING = true,
  HOLD = true,
  CANCELLED = true,
  CANCELED = true,
}

---Strip a leading TODO keyword / `[#A]` priority and trailing `:tags:`.
---@param text string
---@return string
local function clean(text)
  text = text:gsub("^%s+", "")
  local kw, rest = text:match "^(%u+)%s+(.*)$"
  if kw and KEYWORDS[kw] then
    text = rest
  end
  text = text:gsub("^%[#%w%]%s*", "")
  text = text:gsub("%s+:[%w_@#%%:]+:%s*$", "")
  text = text:gsub("%s+$", "")
  return text
end

-- Process one line; a bare `return` skips the rest.
---@param i integer
---@param line string
function Org:scan(i, line)
  -- Source blocks: #+BEGIN_SRC <lang> ... #+END_SRC (case-insensitive).
  local lang = line:match "^%s*#%+[Bb][Ee][Gg][Ii][Nn]_[Ss][Rr][Cc]%s*(%S*)"
  if lang ~= nil then
    self.in_src = true
    if self:enabled "code" then
      self:add { lnum = i, level = self:child_level(), kind = "code", text = lang ~= "" and lang or "code" }
    end
    return
  end
  if line:match "^%s*#%+[Ee][Nn][Dd]_[Ss][Rr][Cc]" then
    self.in_src = false
    return
  end
  if self.in_src then
    return
  end

  -- Headings: leading stars, depth = level (e.g. `** TODO Title :tag:`).
  local stars, rest = line:match "^(%*+)%s+(.*)$"
  if stars then
    self.head_level = #stars
    if self:enabled "heading" then
      local text = clean(rest)
      self:add { lnum = i, level = #stars, kind = "heading", text = text ~= "" and text or "(untitled)" }
    end
    return
  end

  -- Links: [[target][description]] or bare [[target]].
  if self:enabled "link" then
    for inner in line:gmatch "%[%[(.-)%]%]" do
      local _, desc = inner:match "^(.-)%]%[(.+)$"
      local text = desc or inner
      if text ~= "" then
        self:add { lnum = i, level = self:child_level(), kind = "link", text = text }
      end
    end
  end
end

---Scan an Org buffer line-by-line, emitting typed entries (unsorted).
---@return TocEntry[]
function Org:parse()
  for i, line in ipairs(self:lines()) do
    self:scan(i, line)
  end
  return self.entries
end

return Org
