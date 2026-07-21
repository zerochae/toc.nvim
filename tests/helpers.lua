-- Shared fixtures and helpers for the toc.nvim spec files. Each spec loads this
-- with `dofile` (tests/ is not on package.path) via its own directory.
local M = {}

M.toc = require "toc"
M.view = require "toc.view"
M.parser = require "toc.parser"

local dir = vim.fn.tempname()
vim.fn.mkdir(dir, "p")

---@param name string
---@param lines string[]
---@return string path
function M.fixture(name, lines)
  local path = dir .. "/" .. name
  vim.fn.writefile(lines, path)
  return path
end

M.A = M.fixture("a.md", {
  "# Title One",
  "",
  "## Section A",
  "",
  "```",
  "# fake heading inside code",
  "```",
  "",
  "### Sub A1",
  "## Section B",
  "",
  "Setext One",
  "==========",
})
M.B = M.fixture("b.md", {
  "# Bravo Doc",
  "## Bravo Two",
  "### Bravo Three",
})
M.C = M.fixture("c.md", {
  "# This is an extremely long heading that should certainly overflow the panel",
})
M.D = M.fixture("d.md", {
  "# Doc",
  "## Tasks",
  "- [ ] todo one",
  "- [x] done two",
  "## Code",
  "```lua",
  "print(1)",
  "```",
  "## Notes",
  "> [!NOTE] remember this",
  "## Data",
  "| A | B |",
  "| - | - |",
  "| 1 | 2 |",
  "## Media",
  "![diagram](img.png)",
  "[ref link](http://x)",
})

-- Headings only; other kinds off. Provided `elements` overrides merge on top.
M.HEADINGS_ONLY = {
  heading = { enable = true },
  task = { enable = false },
  code = { enable = false },
  callout = { enable = false },
  table = { enable = false },
  image = { enable = false },
  link = { enable = false },
  bullet = { enable = false },
}

-- Open `file` fresh with the given options (auto-open off, headings-only base).
---@param file string
---@param opts? table
---@return View
function M.open(file, opts)
  opts = opts or {}
  opts.elements = vim.tbl_deep_extend("force", vim.deepcopy(M.HEADINGS_ONLY), opts.elements or {})
  M.view.close()
  M.toc.setup(vim.tbl_extend("force", { auto_enabled = false }, opts))
  vim.cmd "silent! %bwipeout!"
  vim.cmd("edit " .. vim.fn.fnameescape(file))
  M.toc.open()
  -- open() always leaves a live panel, so state() is non-nil here.
  return M.view.state() --[[@as View]]
end

---@param buf integer
---@param name string namespace name
function M.marks(buf, name)
  return vim.api.nvim_buf_get_extmarks(buf, vim.api.nvim_get_namespaces()[name], 0, -1, { details = true })
end

-- Whole-buffer text of the TOC panel, joined for substring assertions.
---@param buf integer
---@return string
function M.joined_lines(buf)
  return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
end

---@param entries TocEntry[]
---@return table<string, integer>
function M.kind_counts(entries)
  local counts = {}
  for _, e in ipairs(entries) do
    counts[e.kind] = (counts[e.kind] or 0) + 1
  end
  return counts
end

---@param entries TocEntry[]
---@return table<string, TocEntry>
function M.first_by_kind(entries)
  local by_kind = {}
  for _, e in ipairs(entries) do
    by_kind[e.kind] = by_kind[e.kind] or e
  end
  return by_kind
end

return M
