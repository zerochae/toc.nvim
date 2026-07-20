local config = require "toc.config"

local M = {}

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

---Scan a Markdown buffer line-by-line, emitting typed entries (unsorted).
---@param bufnr integer
---@return TocEntry[]
function M.parse(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local el = config.options.elements
  local entries = {}
  local fence = nil
  local head_level = 0

  ---@param kind string
  ---@return boolean
  local function on(kind)
    return el[kind] ~= nil and el[kind].enable
  end

  -- Non-heading elements nest one level below the current heading.
  local function child_level(extra)
    return head_level + 1 + (extra or 0)
  end
  local function add(entry)
    entry.ord = #entries + 1 -- preserves document order for a stable sort
    entries[#entries + 1] = entry
  end

  -- Process one line; a bare `return` skips the rest (acts like `continue`).
  local function scan(i, line)
    local fence_marker = line:match "^%s*(```+)" or line:match "^%s*(~~~+)"
    if fence_marker then
      if not fence then
        -- Store the full marker; a closing fence must be at least as long (CommonMark).
        fence = fence_marker
        if on("code") then
          add { lnum = i, level = child_level(), kind = "code", text = line:match "^%s*[`~]+%s*([%w_%-%+%.]+)" or "code" }
        end
      elseif fence_marker:sub(1, 1) == fence:sub(1, 1) and #fence_marker >= #fence then
        fence = nil
      end
      return
    end
    if fence then
      return
    end

    local hashes, rest = line:match "^(#+)%s+(.*)$"
    if hashes and #hashes <= 6 then
      head_level = #hashes
      if on("heading") then
        add { lnum = i, level = head_level, kind = "heading", text = clean(rest) }
      end
      return
    end

    -- Raw HTML headings, e.g. <h2 id="x">Title</h2>.
    local html_level, html_text = line:match "^%s*<[Hh]([1-6])[^>]*>(.-)</[Hh][1-6]>"
    if not html_level then
      html_level = line:match "^%s*<[Hh]([1-6])[^>]*>%s*$"
      html_text = ""
    end
    if html_level then
      head_level = tonumber(html_level) or head_level
      if on("heading") then
        add { lnum = i, level = head_level, kind = "heading", text = clean(html_text) }
      end
      return
    end

    local nextline = lines[i + 1]
    if nextline and #line:gsub("%s", "") > 0 and not line:match "^%s*[>|%-%*%+#]" then
      local setext_level
      if nextline:match "^%s*=+%s*$" then
        setext_level = 1
      elseif nextline:match "^%s*%-%-%-+%s*$" then
        setext_level = 2
      end
      if setext_level then
        head_level = setext_level
        if on("heading") then
          add { lnum = i, level = setext_level, kind = "heading", text = clean(line) }
        end
        return
      end
    end

    local t_indent, t_mark, t_rest = line:match "^(%s*)[%-%*%+]%s+%[(.)%]%s+(.*)$"
    if t_mark then
      if on("task") then
        add {
          lnum = i,
          level = child_level(math.floor(#t_indent / 2)),
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
      if on("callout") then
        local title = line:match "^%s*>%s*%[!%w+%]%s*(.*)$"
        title = (title and title ~= "") and clean(title) or ctype:upper()
        add { lnum = i, level = child_level(), kind = "callout", text = title, label = ctype:lower() }
      end
      return
    end

    if line:match "^%s*|.*|%s*$" and (lines[i + 1] or ""):match "^%s*|?[%s:|%-]+%-[%s:|%-]*$" then
      if on("table") then
        add { lnum = i, level = child_level(), kind = "table", text = clean(line:match "^%s*|%s*([^|]-)%s*|" or "table") }
      end
      return
    end

    -- When the line is a bullet, its inline links/images nest one level under it.
    local b_indent, b_rest = line:match "^(%s*)[%-%*%+]%s+(.*)$"
    local bullet = b_rest ~= nil and not b_rest:match "^%[.%]" and on("bullet")
    local bullet_level = bullet and child_level(math.floor(#b_indent / 2)) or nil
    local inline_level = bullet_level and bullet_level + 1 or child_level()

    if on("image") then
      for alt in line:gmatch "!%[([^%]]*)%]%b()" do
        add { lnum = i, level = inline_level, kind = "image", text = alt ~= "" and alt or "image" }
      end
    end
    if on("link") then
      for txt in line:gmatch "[^!]%[([^%]]+)%]%b()" do
        add { lnum = i, level = inline_level, kind = "link", text = clean(txt) }
      end
      local lead = line:match "^%[([^%]]+)%]%b()"
      if lead then
        add { lnum = i, level = inline_level, kind = "link", text = clean(lead) }
      end
    end
    if bullet then
      add { lnum = i, level = bullet_level, kind = "bullet", text = clean(b_rest) }
    end
  end

  for i, line in ipairs(lines) do
    scan(i, line)
  end
  return entries
end

return M
