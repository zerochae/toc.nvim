local Parser = require "toc.parsers.base"
local html = require "toc.parsers.html_utils"

---@class Markdown : Parser
---@field lines string[]
---@field fence string|nil the open fence marker, if inside a code fence
---@field skip_until integer lines up to here are consumed (e.g. an HTML table)
local Markdown = setmetatable({}, { __index = Parser })
Markdown.__index = Markdown

---@param bufnr integer
---@return Markdown
function Markdown.new(bufnr)
  local self = Parser.new(bufnr) --[[@as Markdown]]
  self.fence = nil
  self.skip_until = 0
  return setmetatable(self, Markdown)
end

---@param text string
---@return string
local function clean(text)
  text = text:gsub("^%s*#+%s*", "")
  text = text:gsub("%s*#+%s*$", "")
  text = text:gsub("%[([^%]]*)%]%b()", "%1")
  text = text:gsub("<[^>]->", "")
  text = text:gsub("[`*_~]", "")
  text = text:gsub("^%s+", "")
  text = text:gsub("%s+$", "")
  return text
end

-- Process one line; a bare `return` skips the rest (acts like `continue`).
---@param i integer
---@param line string
function Markdown:scan(i, line)
  if i <= self.skip_until then
    return
  end

  local fence_marker = line:match "^%s*(```+)" or line:match "^%s*(~~~+)"
  if fence_marker then
    if not self.fence then
      -- Store the full marker; a closing fence must be at least as long (CommonMark).
      self.fence = fence_marker
      if self:enabled "code" then
        self:add {
          lnum = i,
          level = self:child_level(),
          kind = "code",
          text = line:match "^%s*[`~]+%s*([%w_%-%+%.]+)" or "code",
        }
      end
    elseif fence_marker:sub(1, 1) == self.fence:sub(1, 1) and #fence_marker >= #self.fence then
      self.fence = nil
    end
    return
  end
  if self.fence then
    return
  end

  local hashes, rest = line:match "^(#+)%s+(.*)$"
  if hashes and #hashes <= 6 then
    self.head_level = #hashes
    if self:enabled "heading" then
      self:add { lnum = i, level = self.head_level, kind = "heading", text = clean(rest) }
    end
    return
  end

  -- Raw HTML headings, e.g. <h2 id="x">Title</h2> (shared with the html parser).
  local html_level, html_text = html.heading(line)
  if html_level then
    self.head_level = html_level
    if self:enabled "heading" then
      html_text = clean(html_text or "")
      self:add {
        lnum = i,
        level = self.head_level,
        kind = "heading",
        text = html_text ~= "" and html_text or "(untitled)",
      }
    end
    return
  end

  local nextline = self.lines[i + 1]
  if nextline and #line:gsub("%s", "") > 0 and not line:match "^%s*[>|%-%*%+#]" then
    local setext_level
    if nextline:match "^%s*=+%s*$" then
      setext_level = 1
    elseif nextline:match "^%s*%-%-%-+%s*$" then
      setext_level = 2
    end
    if setext_level then
      self.head_level = setext_level
      if self:enabled "heading" then
        self:add { lnum = i, level = setext_level, kind = "heading", text = clean(line) }
      end
      return
    end
  end

  local t_indent, t_mark, t_rest = line:match "^(%s*)[%-%*%+]%s+%[(.)%]%s+(.*)$"
  if t_mark then
    if self:enabled "task" then
      self:add {
        lnum = i,
        level = self:child_level(math.floor(#t_indent / 2)),
        kind = "task",
        text = clean(t_rest),
        done = t_mark ~= " ",
        state = t_mark,
      }
    end
    return
  end

  local ctype = line:match "^%s*>%s*%[!(%w+)%]"
  if ctype then
    if self:enabled "callout" then
      local title = line:match "^%s*>%s*%[!%w+%]%s*(.*)$"
      title = (title and title ~= "") and clean(title) or ctype:upper()
      self:add { lnum = i, level = self:child_level(), kind = "callout", text = title, label = ctype:lower() }
    end
    return
  end

  if line:match "^%s*|.*|%s*$" and (self.lines[i + 1] or ""):match "^%s*|?[%s:|%-]+%-[%s:|%-]*$" then
    if self:enabled "table" then
      self:add {
        lnum = i,
        level = self:child_level(),
        kind = "table",
        text = clean(line:match "^%s*|%s*([^|]-)%s*|" or "table"),
      }
    end
    return
  end

  -- HTML <table> (spans lines): label from its caption/first <th> (shared).
  -- Consumed rows are skipped so cell content isn't re-scanned as entries.
  if self:enabled "table" and line:match "^%s*<[Tt][Aa][Bb][Ll][Ee][%s>]" then
    local parts, close = { line }, nil
    for j = i + 1, #self.lines do
      parts[#parts + 1] = self.lines[j]
      if self.lines[j]:match "</[Tt][Aa][Bb][Ll][Ee]>" then
        close = j
        break
      end
    end
    -- An unclosed <table> consumes to end-of-buffer so its cells are never
    -- re-scanned as stray entries (rather than being silently truncated).
    self.skip_until = close or #self.lines
    self:add {
      lnum = i,
      level = self:child_level(),
      kind = "table",
      text = clean(html.table_label(table.concat(parts, "\n"))),
    }
    return
  end

  -- When the line is a bullet, its inline links/images nest one level under it.
  local b_indent, b_rest = line:match "^(%s*)[%-%*%+]%s+(.*)$"
  local bullet = b_rest ~= nil and not b_rest:match "^%[.%]" and self:enabled "bullet"
  local bullet_level = bullet and self:child_level(math.floor(#b_indent / 2)) or nil
  local inline_level = bullet_level and bullet_level + 1 or self:child_level()

  if self:enabled "image" then
    for alt in line:gmatch "!%[([^%]]*)%]%b()" do
      self:add { lnum = i, level = inline_level, kind = "image", text = alt ~= "" and alt or "image" }
    end
    -- HTML <img> tags (shared with the html parser).
    for _, alt in ipairs(html.images(line)) do
      self:add { lnum = i, level = inline_level, kind = "image", text = clean(alt) }
    end
  end
  if self:enabled "link" then
    for txt in line:gmatch "[^!]%[([^%]]+)%]%b()" do
      self:add { lnum = i, level = inline_level, kind = "link", text = clean(txt) }
    end
    local lead = line:match "^%[([^%]]+)%]%b()"
    if lead then
      self:add { lnum = i, level = inline_level, kind = "link", text = clean(lead) }
    end
    -- HTML <a href> links (shared with the html parser).
    for _, text in ipairs(html.links(line)) do
      self:add { lnum = i, level = inline_level, kind = "link", text = clean(text) }
    end
  end
  if self:enabled "summary" then
    for _, text in ipairs(html.summaries(line)) do
      self:add { lnum = i, level = inline_level, kind = "summary", text = clean(text) }
    end
  end
  if self:enabled "definition" then
    for _, text in ipairs(html.terms(line)) do
      self:add { lnum = i, level = inline_level, kind = "definition", text = clean(text) }
    end
  end
  if bullet then
    self:add { lnum = i, level = bullet_level or self:child_level(), kind = "bullet", text = clean(b_rest) }
  end
end

---A leading YAML (`---`) or TOML (`+++`) front matter block spans line 1 to its
---closing fence; its keys/values must not be scanned as entries.
---@return integer lines consumed (0 when there is no front matter)
function Markdown:front_matter()
  local open = self.lines[1] and self.lines[1]:match "^(%-%-%-)%s*$"
  open = open or (self.lines[1] and self.lines[1]:match "^(%+%+%+)%s*$")
  if not open then
    return 0
  end
  for j = 2, #self.lines do
    if self.lines[j]:gsub("%s+$", "") == open then
      return j
    end
  end
  -- Unclosed: leave the buffer alone rather than swallowing all of it.
  return 0
end

---Scan a Markdown buffer line-by-line, emitting typed entries (unsorted).
---@return TocEntry[]
function Markdown:parse()
  self.lines = self:lines()
  self.skip_until = self:front_matter()
  for i, line in ipairs(self.lines) do
    self:scan(i, line)
  end
  return self.entries
end

return Markdown
