-- toc.nvim behaviour tests.
-- Run: nvim --headless -u tests/minimal_init.lua -c "luafile tests/toc_spec.lua"

local toc = require "toc"
local view = require "toc.view"
local parser = require "toc.parser"

-- ── tiny assertion harness ──────────────────────────────────────────────────
local passed, failed = 0, 0
local function ok(name, cond, msg)
  if cond then
    passed = passed + 1
    print("  ✓ " .. name)
  else
    failed = failed + 1
    print("  ✗ " .. name .. (msg and ("  → " .. msg) or ""))
  end
end
local function eq(name, got, want)
  ok(name, vim.deep_equal(got, want), string.format("want %s, got %s", vim.inspect(want), vim.inspect(got)))
end

-- ── fixtures ────────────────────────────────────────────────────────────────
local dir = vim.fn.tempname()
vim.fn.mkdir(dir, "p")
local function fixture(name, lines)
  local path = dir .. "/" .. name
  vim.fn.writefile(lines, path)
  return path
end

local A = fixture("a.md", {
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
local B = fixture("b.md", {
  "# Bravo Doc",
  "## Bravo Two",
  "### Bravo Three",
})
local C = fixture("c.md", {
  "# This is an extremely long heading that should certainly overflow the panel",
})

-- Headings only; other kinds off. Provided `elements` overrides merge on top.
local HEADINGS_ONLY = {
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
local function open(file, opts)
  opts = opts or {}
  opts.elements = vim.tbl_deep_extend("force", vim.deepcopy(HEADINGS_ONLY), opts.elements or {})
  view.close()
  toc.setup(vim.tbl_extend("force", { auto_enabled = false }, opts))
  vim.cmd "silent! %bwipeout!"
  vim.cmd("edit " .. vim.fn.fnameescape(file))
  toc.open()
  return view.state()
end

local function marks(buf, name)
  return vim.api.nvim_buf_get_extmarks(buf, vim.api.nvim_get_namespaces()[name], 0, -1, { details = true })
end

local D = fixture("d.md", {
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

-- ── parser (headings only) ──────────────────────────────────────────────────
print "parser"
do
  toc.setup { auto_enabled = false, elements = vim.deepcopy(HEADINGS_ONLY) }
  vim.cmd("edit " .. vim.fn.fnameescape(A))
  local h = parser.parse(0)
  eq("heading count (fenced code skipped)", #h, 5)
  eq("first heading text stripped of #", h[1].text, "Title One")
  eq("first heading kind", h[1].kind, "heading")
  eq("first heading level", h[1].level, 1)
  eq("nested heading level", h[3].level, 3)
  eq("setext heading detected", h[5].text, "Setext One")
  eq("setext heading level", h[5].level, 1)
  eq("heading line number", h[4].lnum, 10)
end

-- ── parser: nested fences (4-backtick wrapping 3-backtick) ──────────────────
print "nested fences"
do
  local N = fixture("n.md", {
    "# Real Heading",
    "````markdown",
    "```lua",
    "# not a heading",
    "```",
    "````",
    "## After Fence",
  })
  toc.setup { auto_enabled = false, elements = vim.deepcopy(HEADINGS_ONLY) }
  vim.cmd("edit " .. vim.fn.fnameescape(N))
  local h = parser.parse(0)
  eq("inner fenced # not treated as heading", #h, 2)
  eq("heading after outer fence found", h[2].text, "After Fence")
end

-- ── a bullet containing a link yields both a bullet and an anchor ───────────
print "bullet + link"
do
  local BL = fixture("bl.md", {
    "# Doc",
    "- see [markview](https://x) here",
  })
  toc.setup { auto_enabled = false, elements = { link = { enable = true }, bullet = { enable = true } } }
  vim.cmd("edit " .. vim.fn.fnameescape(BL))
  local by_kind = {}
  for _, e in ipairs(parser.parse(0)) do
    by_kind[e.kind] = e
  end
  eq("inline link extracted as anchor", by_kind.link.text, "markview")
  eq("bullet still emitted", by_kind.bullet.text, "see markview here")
  eq("anchor nests one level under the bullet", by_kind.link.level, by_kind.bullet.level + 1)
end

-- ── parser dispatches on filetype: Vim help sections ───────────────────────
print "help filetype"
do
  local H = fixture("h.txt", {
    "*mine.txt*  My help",
    "",
    "==============================================================================",
    "SECTION ONE                                                        *mine-one*",
    "",
    "body text",
    "",
    "------------------------------------------------------------------------------",
    "1.1 Subsection                                                 *mine-one-sub*",
    "",
    "==============================================================================",
    "SECTION TWO                                                        *mine-two*",
  })
  toc.setup { auto_enabled = false }
  vim.cmd("edit " .. vim.fn.fnameescape(H))
  vim.bo.filetype = "help"
  local h = parser.parse(0)
  eq("help section count", #h, 3)
  eq("level-1 section, tag stripped", h[1].text, "SECTION ONE")
  eq("level-1 level", h[1].level, 1)
  eq("subsection is level 2", h[2].level, 2)
  eq("subsection text", h[2].text, "1.1 Subsection")
  eq("second section", h[3].text, "SECTION TWO")
end

-- ── help extras: ~ subheadings, tags, code, callouts ────────────────────────
print "help elements"
do
  local H = fixture("h2.txt", {
    "==============================================================================",
    "INTRO                                                              *h2-intro*",
    "",
    "Getting Started ~",
    "Run it: >",
    "    :Cmd go",
    "<",
    "Note: careful here.",
    "Body with a *h2-tag* target.",
  })
  toc.setup {
    auto_enabled = false,
    elements = { link = { enable = true }, code = { enable = true }, callout = { enable = true } },
  }
  vim.cmd("edit " .. vim.fn.fnameescape(H))
  vim.bo.filetype = "help"
  local kinds = {}
  for _, e in ipairs(parser.parse(0)) do
    kinds[e.kind] = (kinds[e.kind] or 0) + 1
  end
  ok("two headings (section + ~ subheading)", kinds.heading == 2)
  ok("code block indexed", kinds.code == 1)
  ok("Note callout indexed", kinds.callout == 1)
  ok("body tag indexed as anchor", kinds.link == 1)
end

-- ── parser: raw HTML headings ───────────────────────────────────────────────
print "html headings"
do
  local E = fixture("e.md", {
    "# Markdown H1",
    '<h2 id="sec">HTML Section</h2>',
    "<h3>Sub</h3>",
  })
  toc.setup { auto_enabled = false, elements = vim.deepcopy(HEADINGS_ONLY) }
  vim.cmd("edit " .. vim.fn.fnameescape(E))
  local h = parser.parse(0)
  eq("html + markdown heading count", #h, 3)
  eq("html h2 level", h[2].level, 2)
  eq("html h2 text (tags/attrs stripped)", h[2].text, "HTML Section")
  eq("html h3 level", h[3].level, 3)
end

-- ── parser: inline HTML in markdown shares the html scanner ─────────────────
print "html inline in markdown"
do
  local E = fixture("inline.md", {
    "# Title",
    '<p>see <a href="u">the guide</a></p>',
    '<img alt="diagram" src="d/e.png">',
  })
  toc.setup { auto_enabled = false, elements = { link = { enable = true }, image = { enable = true } } }
  vim.cmd("edit " .. vim.fn.fnameescape(E))
  local kinds = {}
  for _, e in ipairs(parser.parse(0)) do
    kinds[e.kind] = (kinds[e.kind] or 0) + 1
  end
  ok("inline <a> link parsed in markdown", (kinds.link or 0) == 1)
  ok("inline <img> image parsed in markdown", (kinds.image or 0) == 1)
end

-- ── parser: markdown-embedded HTML headings are cleaned of markdown syntax ───
print "html heading cleaning"
do
  local E = fixture("clean.md", {
    "<h2>Hello **world** and `code`</h2>",
    "<h3>[Link](url)</h3>",
  })
  toc.setup { auto_enabled = false, elements = vim.deepcopy(HEADINGS_ONLY) }
  vim.cmd("edit " .. vim.fn.fnameescape(E))
  local h = parser.parse(0)
  eq("markdown emphasis stripped from HTML heading", h[1].text, "Hello world and code")
  eq("markdown link stripped from HTML heading", h[2].text, "Link")
end

-- ── parser: HTML table cell content does not leak as separate entries ────────
print "html table no leak"
do
  local E = fixture("leak.md", {
    "# Title",
    "<table>",
    '  <caption>Refs</caption>',
    '  <tr><td><a href="u">cell link</a></td></tr>',
    "</table>",
    "after",
  })
  toc.setup { auto_enabled = false, elements = { table = { enable = true }, link = { enable = true } } }
  vim.cmd("edit " .. vim.fn.fnameescape(E))
  local by_kind = {}
  for _, e in ipairs(parser.parse(0)) do
    by_kind[e.kind] = (by_kind[e.kind] or 0) + 1
  end
  eq("one table entry", by_kind.table, 1)
  ok("no link leaked from table cell", (by_kind.link or 0) == 0)
end

-- ── parser: multiline inline HTML in markdown (details, table, dl) ───────────
print "html blocks in markdown"
do
  local E = fixture("blocks.md", {
    "# Title",
    "<details>",
    "  <summary>Expand me</summary>",
    "</details>",
    "<table>",
    "  <caption>Scores</caption>",
    "  <tr><th>N</th></tr>",
    "</table>",
    "<dl>",
    "  <dt>Term</dt>",
    "</dl>",
  })
  toc.setup { auto_enabled = false, elements = { summary = { enable = true }, table = { enable = true }, definition = { enable = true } } }
  vim.cmd("edit " .. vim.fn.fnameescape(E))
  local by_kind = {}
  for _, e in ipairs(parser.parse(0)) do
    by_kind[e.kind] = by_kind[e.kind] or e
  end
  eq("inline <summary> in markdown", by_kind.summary and by_kind.summary.text, "Expand me")
  eq("multiline <table> caption in markdown", by_kind.table and by_kind.table.text, "Scores")
  eq("inline <dt> in markdown", by_kind.definition and by_kind.definition.text, "Term")
end

-- ── parser dispatches on filetype: HTML (regex fallback path) ───────────────
print "html filetype"
do
  local H = fixture("h.html", {
    "<h1>Title</h1>",
    "<section>",
    '  <h2 id="a">Getting Started</h2>',
    '  <p>see <a href="u">the guide</a> here</p>',
    '  <img alt="diagram" src="d/e.png">',
    "</section>",
  })
  toc.setup { auto_enabled = false, elements = { link = { enable = true }, image = { enable = true } } }
  vim.cmd("edit " .. vim.fn.fnameescape(H))
  vim.bo.filetype = "html"
  local h = parser.parse(0)
  local kinds = {}
  for _, e in ipairs(h) do
    kinds[e.kind] = (kinds[e.kind] or 0) + 1
  end
  ok("h1/h2 headings parsed", kinds.heading == 2)
  ok("<a> link parsed", kinds.link == 1)
  ok("<img> image parsed", kinds.image == 1)
  eq("first heading text", h[1].text, "Title")
end

-- ── parser: HTML details/summary, table, definition list ────────────────────
print "html rich elements"
do
  local H = fixture("rich.html", {
    "<h1>Doc</h1>",
    "<details>",
    "  <summary>Advanced options</summary>",
    "  <p>hidden</p>",
    "</details>",
    "<table>",
    "  <caption>Feature matrix</caption>",
    "  <tr><th>Name</th><th>OK</th></tr>",
    "</table>",
    "<dl>",
    "  <dt>TOC</dt>",
    "  <dd>Table of contents.</dd>",
    "</dl>",
  })
  toc.setup { auto_enabled = false, elements = { summary = { enable = true }, table = { enable = true }, definition = { enable = true } } }
  vim.cmd("edit " .. vim.fn.fnameescape(H))
  vim.bo.filetype = "html"
  local h = parser.parse(0)
  local by_kind = {}
  for _, e in ipairs(h) do
    by_kind[e.kind] = by_kind[e.kind] or e
  end
  ok("<summary> parsed", by_kind.summary ~= nil)
  eq("summary text", by_kind.summary and by_kind.summary.text, "Advanced options")
  ok("<table> parsed", by_kind.table ~= nil)
  eq("table caption used", by_kind.table and by_kind.table.text, "Feature matrix")
  ok("<dt> definition parsed", by_kind.definition ~= nil)
  eq("definition term text", by_kind.definition and by_kind.definition.text, "TOC")
end

-- ── parser: typed elements ──────────────────────────────────────────────────
print "elements"
do
  toc.setup {
    auto_enabled = false,
    elements = { task = { enable = true }, code = { enable = true }, callout = { enable = true }, table = { enable = true }, image = { enable = true }, link = { enable = true } },
  }
  vim.cmd("edit " .. vim.fn.fnameescape(D))
  local kinds = {}
  for _, e in ipairs(parser.parse(0)) do
    kinds[e.kind] = (kinds[e.kind] or 0) + 1
  end
  ok("task entries parsed", (kinds.task or 0) == 2)
  ok("code entry parsed", (kinds.code or 0) == 1)
  ok("callout entry parsed", (kinds.callout or 0) == 1)
  ok("table entry parsed", (kinds.table or 0) == 1)
  ok("image entry parsed", (kinds.image or 0) == 1)
  ok("link entry parsed", (kinds.link or 0) >= 1)

  local by_kind = {}
  for _, e in ipairs(parser.parse(0)) do
    by_kind[e.kind] = by_kind[e.kind] or e
  end
  eq("code entry carries language", by_kind.code.text, "lua")
  ok("task done state captured", parser.parse(0)[4].done == true)
end

-- ── task checkbox states map to per-state glyphs ────────────────────────────
print "task states"
do
  local TS = fixture("ts.md", {
    "# Doc",
    "- [ ] todo",
    "- [x] done",
    "- [/] in progress",
    "- [?] question",
  })
  local st = open(TS, {
    title = false,
    mode = "full",
    elements = {
      task = { enable = true, done = "DONE", todo = "TODO", states = { ["/"] = "PROG", ["?"] = "QUES" } },
    },
  })
  local joined = table.concat(vim.api.nvim_buf_get_lines(st.toc_buf, 0, -1, false), "\n")
  ok("unchecked uses todo glyph", joined:find("TODO", 1, true) ~= nil)
  ok("checked uses done glyph", joined:find("DONE", 1, true) ~= nil)
  ok("custom state / uses its glyph", joined:find("PROG", 1, true) ~= nil)
  ok("custom state ? uses its glyph", joined:find("QUES", 1, true) ~= nil)
end

-- ── labels = false hides prefixes, keeps per-kind numbering ─────────────────
print "labels toggle"
do
  local st = open(D, {
    title = false,
    labels = false,
    elements = { task = { enable = true }, code = { enable = true }, image = { enable = true } },
  })
  local joined = table.concat(vim.api.nvim_buf_get_lines(st.toc_buf, 0, -1, false), "\n")
  ok("no heading label prefix", joined:find("heading", 1, true) == nil)
  ok("no task label prefix", joined:find("task ", 1, true) == nil)
  ok("no image label prefix", joined:find("image ", 1, true) == nil)
  ok("heading number still shown", joined:find("1.1", 1, true) ~= nil)
  ok("code language still shown", joined:find("[lua]", 1, true) ~= nil)
end

-- ── callouts labelled by their own type ─────────────────────────────────────
print "callout labels"
do
  local CO = fixture("co.md", {
    "# Doc",
    "> [!NOTE] first",
    "> [!WARNING] second",
    "> [!NOTE] third",
    "> [!TIP] fourth",
  })
  local st = open(CO, {
    title = false,
    mode = "glyph-only",
    elements = { callout = { enable = true } },
  })
  local joined = table.concat(vim.api.nvim_buf_get_lines(st.toc_buf, 0, -1, false), "\n")
  ok("note counted per type (note 1)", joined:find("note 1", 1, true) ~= nil)
  ok("second note is note 2", joined:find("note 2", 1, true) ~= nil)
  ok("warning labelled by type", joined:find("warning 1", 1, true) ~= nil)
  ok("tip labelled by type", joined:find("tip 1", 1, true) ~= nil)

  -- per-type glyphs + highlights
  local st2 = open(CO, {
    title = false,
    mode = "glyph-only",
    elements = {
      callout = {
        enable = true,
        types = { note = "N>", warning = "W>", tip = "T>" },
        type_hls = { warning = "MyWarnHl" },
      },
    },
  })
  local j2 = table.concat(vim.api.nvim_buf_get_lines(st2.toc_buf, 0, -1, false), "\n")
  ok("note uses its glyph", j2:find("N>", 1, true) ~= nil)
  ok("warning uses its glyph", j2:find("W>", 1, true) ~= nil)
  ok("tip uses its glyph", j2:find("T>", 1, true) ~= nil)
  local hls = {}
  local ns = vim.api.nvim_get_namespaces()["toc.nvim"]
  for _, m in ipairs(vim.api.nvim_buf_get_extmarks(st2.toc_buf, ns, 0, -1, { details = true })) do
    hls[tostring(m[4].hl_group)] = true
  end
  ok("warning uses its type_hl", hls["MyWarnHl"] == true)
end

-- ── non-heading label (anchor1 / code1 …) in glyph-only ─────────────────────
print "element labels"
do
  local st = open(D, {
    mode = "glyph-only",
    title = false,
    elements = { task = { enable = true }, code = { enable = true }, callout = { enable = true }, table = { enable = true }, image = { enable = true }, link = { enable = true } },
  })
  local joined = table.concat(vim.api.nvim_buf_get_lines(st.toc_buf, 0, -1, false), "\n")
  ok("code label carries language", joined:find("code 1 [lua]", 1, true) ~= nil)
  ok("image labelled 'image 1'", joined:find("image 1", 1, true) ~= nil)
  ok("link labelled 'anchor 1'", joined:find("anchor 1", 1, true) ~= nil)
  ok("heading keeps section number", joined:find("1.1", 1, true) ~= nil)

  -- full mode: language shown once in the label, not duplicated as text.
  local stf = open(D, {
    mode = "full",
    title = false,
    elements = { code = { enable = true } },
  })
  local jf = table.concat(vim.api.nvim_buf_get_lines(stf.toc_buf, 0, -1, false), "\n")
  ok("full mode code shows [lua] once", jf:find("code 1 [lua]", 1, true) ~= nil)
  ok("no duplicated lua text", jf:find("%[lua%] lua") == nil)
end

-- ── render / glyphs / title ───────────────────────────────────────────────
print "render"
do
  local st = open(A, { title = "TOC" })
  local lines = vim.api.nvim_buf_get_lines(st.toc_buf, 0, -1, false)
  ok("title present", lines[1]:find("TOC", 1, true) ~= nil)
  ok("root heading has no connector", lines[3]:find("├", 1, true) == nil and lines[3]:find("╰", 1, true) == nil)
  ok("nested heading has branch glyph", lines[4]:find("├", 1, true) or lines[4]:find("╰", 1, true))
  local joined = table.concat(lines, "\n")
  ok("contains heading text", joined:find("Section A", 1, true) ~= nil)
  eq("line maps to source heading 4", st.line_to_heading[st.heading_to_line[4]], 4)

  -- cursor starts on the first entry, not the title line
  eq("cursor opens on first entry", vim.api.nvim_win_get_cursor(st.toc_win)[1], st.heading_to_line[1])
  -- moving above the first entry snaps back to it
  vim.api.nvim_set_current_win(st.toc_win)
  pcall(vim.api.nvim_win_set_cursor, st.toc_win, { 1, 0 })
  vim.api.nvim_exec_autocmds("CursorMoved", { buffer = st.toc_buf })
  eq("cursor clamped to first entry", vim.api.nvim_win_get_cursor(st.toc_win)[1], st.heading_to_line[1])
  -- horizontal movement snaps back to column 0 (vertical-only)
  pcall(vim.api.nvim_win_set_cursor, st.toc_win, { st.heading_to_line[2], 3 })
  vim.api.nvim_exec_autocmds("CursorMoved", { buffer = st.toc_buf })
  eq("cursor snaps to column 0", vim.api.nvim_win_get_cursor(st.toc_win)[2], 0)
end

-- ── highlight mapping: glyph → heading colour, text → Normal ────────────────
print "highlight mapping"
do
  local st = open(A, { title = false, numbers = false })
  local hm = marks(st.toc_buf, "toc.nvim")
  local by_line = {}
  for _, m in ipairs(hm) do
    by_line[m[2]] = by_line[m[2]] or {}
    table.insert(by_line[m[2]], m[4].hl_group)
  end
  local first = by_line[0] or {}
  ok("glyph uses per-level heading highlight", vim.tbl_contains(first, "TocHeading1"))
  ok("text uses TocText (Normal)", vim.tbl_contains(first, "TocText"))
end

-- ── section numbering ───────────────────────────────────────────────────────
print "numbering"
do
  local st = open(A, { title = false, numbers = "nested", elements = { heading = { label = "" } } })
  local lines = vim.api.nvim_buf_get_lines(st.toc_buf, 0, -1, false)
  ok("H1 numbered 1", lines[1]:find(" 1 ", 1, true) or lines[1]:find(" 1$"))
  ok("nested child numbered 1.1", (table.concat(lines, "\n")):find("1.1", 1, true) ~= nil)

  st = open(A, { title = false, numbers = "nested", elements = { heading = { label = "heading" } } })
  local joined = table.concat(vim.api.nvim_buf_get_lines(st.toc_buf, 0, -1, false), "\n")
  ok("heading label prefix applied", joined:find("heading 1.1", 1, true) ~= nil)

  -- level mode: first number is the heading level, second is the nth at that level.
  st = open(A, { title = false, numbers = "level", elements = { heading = { label = "" } } })
  lines = vim.api.nvim_buf_get_lines(st.toc_buf, 0, -1, false)
  ok("level: H1 → 1.1", lines[1]:find("1.1", 1, true) ~= nil)
  local j2 = table.concat(lines, "\n")
  ok("level: an H2 → 2.1", j2:find("2.1", 1, true) ~= nil)
  ok("level: second H2 → 2.2", j2:find("2.2", 1, true) ~= nil)
end

-- ── mode = glyph-only ───────────────────────────────────────────────────────
print "mode=glyph-only"
do
  local st = open(A, { mode = "glyph-only", title = false })
  local joined = table.concat(vim.api.nvim_buf_get_lines(st.toc_buf, 0, -1, false), "\n")
  ok("heading text hidden", joined:find("Title One", 1, true) == nil)
  ok("number still shown", joined:find("1.1", 1, true) ~= nil)
  ok("still maps all 5 headings", vim.tbl_count(st.heading_to_line) == 5)
end

-- ── mode = minimal / text-only ──────────────────────────────────────────────
print "mode variants"
do
  local st = open(A, { mode = "minimal", title = false })
  local l1 = vim.api.nvim_buf_get_lines(st.toc_buf, 0, 1, false)[1]
  ok("minimal hides number", l1:find("1", 1, true) == nil)
  st = open(A, { mode = "text-only", title = false })
  l1 = vim.api.nvim_buf_get_lines(st.toc_buf, 0, 1, false)[1]
  ok("text-only shows text", l1:find("Title One", 1, true) ~= nil)
end

-- ── title = false puts the first heading on line 1 ─────────────────────
print "show_title=false"
do
  local st = open(A, { title = false })
  eq("first heading on line 1", st.heading_to_line[1], 1)
end

-- ── width = "auto" fits the longest line ────────────────────────────────────
print "auto width"
do
  local st = open(A, { width = "auto", padding = 3, title = false })
  local lines = vim.api.nvim_buf_get_lines(st.toc_buf, 0, -1, false)
  local maxw = 0
  for _, l in ipairs(lines) do
    maxw = math.max(maxw, vim.fn.strdisplaywidth(l))
  end
  local w = vim.api.nvim_win_get_width(st.toc_win)
  ok("auto width fits content + padding", w >= maxw and w <= maxw + 3 + 2 + 1, "win=" .. w .. " maxw=" .. maxw)

  -- auto width never exceeds width_max
  local st2 = open(C, { width = "auto", width_max = 24, title = false })
  ok("auto width capped by width_max", vim.api.nvim_win_get_width(st2.toc_win) <= 24)
end

-- ── truncate to width ───────────────────────────────────────────────────────
print "truncate"
do
  local st = open(C, { width = 20, truncate = true, title = false })
  local line = vim.api.nvim_buf_get_lines(st.toc_buf, 0, 1, false)[1]
  ok("line fits panel width", vim.fn.strdisplaywidth(line) <= 20 - 2, "width=" .. vim.fn.strdisplaywidth(line))
  ok("ellipsis appended", line:sub(-3) == "…")
end

-- ── follow: TOC cursor drives source cursor ─────────────────────────────────
print "follow toc→src"
do
  local st = open(A, {})
  vim.api.nvim_set_current_win(st.toc_win)
  vim.api.nvim_win_set_cursor(st.toc_win, { st.heading_to_line[4], 0 })
  vim.api.nvim_exec_autocmds("CursorMoved", { buffer = st.toc_buf })
  eq("source cursor moved to heading 4 line", vim.api.nvim_win_get_cursor(st.src_win)[1], st.headings[4].lnum)
end

-- ── reverse follow: source cursor highlights active heading ─────────────────
print "follow src→toc"
do
  local st = open(A, {})
  vim.api.nvim_set_current_win(st.src_win)
  vim.api.nvim_win_set_cursor(st.src_win, { st.headings[4].lnum + 0, 0 })
  vim.api.nvim_exec_autocmds("CursorMoved", { buffer = st.src_buf })
  local am = marks(st.toc_buf, "toc.nvim.active")
  ok("active marker exists", #am == 1)
  eq("active marker on heading 4 line", am[1] and am[1][2] + 1 or -1, st.heading_to_line[4])
  ok("active marker draws sign", am[1] and am[1][4].sign_text ~= nil)
end

-- ── <CR> jumps to source line and focuses the source window ─────────────────
print "jump <CR>"
do
  local st = open(A, { focus_on_open = true })
  vim.api.nvim_set_current_win(st.toc_win)
  vim.api.nvim_win_set_cursor(st.toc_win, { st.heading_to_line[4], 0 })
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "x", false)
  eq("focus moved to source window", vim.api.nvim_get_current_win(), st.src_win)
  eq("source cursor on heading 4 line", vim.api.nvim_win_get_cursor(st.src_win)[1], st.headings[4].lnum)
end

-- ── beacon flashes then fades ───────────────────────────────────────────────
print "beacon"
do
  local st = open(A, { effects = { beacon = { enable = true, duration = 120, fade_steps = 4 } } })
  vim.api.nvim_set_current_win(st.toc_win)
  vim.api.nvim_win_set_cursor(st.toc_win, { st.heading_to_line[2], 0 })
  vim.api.nvim_exec_autocmds("CursorMoved", { buffer = st.toc_buf })
  ok("beacon mark appears in source", #marks(st.src_buf, "toc.nvim.beacon") == 1)
  vim.wait(500, function()
    return #marks(st.src_buf, "toc.nvim.beacon") == 0
  end, 20)
  ok("beacon fades away", #marks(st.src_buf, "toc.nvim.beacon") == 0)
end

-- ── buffer switch rebinds TOC to the new markdown buffer ────────────────────
print "buffer switch"
do
  local st = open(A, {})
  vim.api.nvim_set_current_win(st.src_win)
  vim.cmd("edit " .. vim.fn.fnameescape(B))
  vim.wait(300, function()
    return view.state().src_buf == vim.api.nvim_get_current_buf()
  end, 20)
  local st2 = view.state()
  eq("rebound to new buffer", st2.src_buf, vim.api.nvim_get_current_buf())
  eq("headings from new buffer", #st2.headings, 3)
  eq("new first heading", st2.headings[1].text, "Bravo Doc")
end

-- ── presets ─────────────────────────────────────────────────────────────────
print "presets"
do
  local function opts()
    return require("toc.config").options
  end

  -- string preset applies its bundle
  open(A, { preset = "minimal" })
  eq("minimal preset sets mode", opts().mode, "minimal")
  eq("minimal preset hides title", opts().title, false)

  -- user options override the preset
  open(A, { preset = "minimal", mode = "full" })
  eq("user option beats preset", opts().mode, "full")

  -- inline table preset
  open(A, { preset = { width = 99 } })
  eq("inline preset applies", opts().width, 99)

  -- plain preset disables markview-derived glyphs (ASCII heading marker)
  open(A, { preset = "plain" })
  eq("plain preset markview off", opts().markview, false)
  eq("plain preset ASCII heading", opts().glyphs.heading[1], "#")
end

-- ── saving re-syncs the TOC even with auto_refresh off ──────────────────────
print "save refresh"
do
  local st = open(A, { auto_refresh = false })
  local before = #st.headings
  vim.api.nvim_buf_set_lines(st.src_buf, 0, 0, false, { "# Brand New Top", "" })
  vim.api.nvim_exec_autocmds("BufWritePost", { buffer = st.src_buf })
  eq("TOC refreshed on save", #view.state().headings, before + 1)
  eq("new heading appears first", view.state().headings[1].text, "Brand New Top")
end

-- ── live refresh debounce ───────────────────────────────────────────────────
print "debounce"
do
  local st = open(A, { auto_refresh = true, refresh_debounce = 0 })
  local before = #st.headings
  vim.api.nvim_buf_set_lines(st.src_buf, 0, 0, false, { "# Now", "" })
  vim.api.nvim_exec_autocmds("TextChanged", { buffer = st.src_buf })
  eq("debounce 0 refreshes immediately", #view.state().headings, before + 1)

  st = open(A, { auto_refresh = true, refresh_debounce = 40 })
  before = #st.headings
  vim.api.nvim_buf_set_lines(st.src_buf, 0, 0, false, { "# Later", "" })
  vim.api.nvim_exec_autocmds("TextChanged", { buffer = st.src_buf })
  vim.wait(300, function()
    return #view.state().headings == before + 1
  end, 10)
  eq("debounced refresh eventually fires", #view.state().headings, before + 1)
end

-- ── health check runs without error ─────────────────────────────────────────
print "health"
do
  ok("health.check is callable", pcall(require("toc.health").check))
end

-- ── auto_close hides the TOC when switching to a non-markdown file ──────────
print "auto_close"
do
  local L = fixture("x.lua", { "local x = 1", "return x" })
  local st = open(A, {})
  ok("open before switch", view.is_open())
  vim.api.nvim_set_current_win(st.src_win)
  vim.cmd("edit " .. vim.fn.fnameescape(L))
  vim.wait(300, function()
    return not view.is_open()
  end, 10)
  ok("closed on non-markdown file", not view.is_open())
end

-- ── auto_enabled opens TOC on markdown filetype ─────────────────────────────
print "auto_enabled"
do
  view.close()
  toc.setup { auto_enabled = true }
  vim.cmd "silent! %bwipeout!"
  vim.cmd("edit " .. vim.fn.fnameescape(A))
  vim.wait(500, function()
    return view.is_open()
  end, 20)
  ok("TOC auto-opened", view.is_open())

  -- HTML files auto-open too (html is a default filetype).
  view.close()
  local H = fixture("auto.html", { "<h1>Title</h1>", "<h2>Sub</h2>" })
  vim.cmd "silent! %bwipeout!"
  vim.cmd("edit " .. vim.fn.fnameescape(H))
  vim.wait(500, function()
    return view.is_open()
  end, 20)
  ok("TOC auto-opened on html", view.is_open())
  view.close()
end

-- ── toggle / close ──────────────────────────────────────────────────────────
print "toggle"
do
  open(A, {})
  ok("open after open()", view.is_open())
  toc.toggle()
  ok("closed after toggle", not view.is_open())
  toc.toggle()
  ok("reopened after toggle", view.is_open())
  toc.close()
  ok("closed after close()", not view.is_open())
end

-- ── summary ─────────────────────────────────────────────────────────────────
print(string.format("\n%d passed, %d failed", passed, failed))
vim.cmd(failed == 0 and "qall!" or "cquit 1")
