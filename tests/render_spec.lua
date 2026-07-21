-- toc.nvim render/layout behaviour (plenary busted).
local here = debug.getinfo(1, "S").source:sub(2)
local h = dofile(vim.fn.fnamemodify(here, ":h") .. "/helpers.lua")
local open, marks, joined_lines = h.open, h.marks, h.joined_lines
local fixture, A, C, D = h.fixture, h.A, h.C, h.D

-- ── task checkbox states map to per-state glyphs ────────────────────────────
describe("render: task states", function()
  local joined
  before_each(function()
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
    joined = joined_lines(st.toc_buf)
  end)

  it("uses the todo glyph for unchecked", function()
    assert.truthy(joined:find("TODO", 1, true))
  end)
  it("uses the done glyph for checked", function()
    assert.truthy(joined:find("DONE", 1, true))
  end)
  it("uses a custom glyph for state /", function()
    assert.truthy(joined:find("PROG", 1, true))
  end)
  it("uses a custom glyph for state ?", function()
    assert.truthy(joined:find("QUES", 1, true))
  end)
end)

-- ── labels = false hides prefixes, keeps per-kind numbering ─────────────────
describe("render: labels toggle", function()
  local joined
  before_each(function()
    local st = open(D, {
      title = false,
      labels = false,
      elements = { task = { enable = true }, code = { enable = true }, image = { enable = true } },
    })
    joined = joined_lines(st.toc_buf)
  end)

  it("hides the heading label prefix", function()
    assert.is_nil(joined:find("heading", 1, true))
  end)
  it("hides the task label prefix", function()
    assert.is_nil(joined:find("task ", 1, true))
  end)
  it("hides the image label prefix", function()
    assert.is_nil(joined:find("image ", 1, true))
  end)
  it("still shows the heading number", function()
    assert.truthy(joined:find("1.1", 1, true))
  end)
  it("still shows the code language", function()
    assert.truthy(joined:find("[lua]", 1, true))
  end)
end)

-- ── callouts labelled by their own type ─────────────────────────────────────
describe("render: callout labels", function()
  local CO = fixture("co.md", {
    "# Doc",
    "> [!NOTE] first",
    "> [!WARNING] second",
    "> [!NOTE] third",
    "> [!TIP] fourth",
  })

  describe("type counting", function()
    local joined
    before_each(function()
      local st = open(CO, { title = false, mode = "glyph-only", elements = { callout = { enable = true } } })
      joined = joined_lines(st.toc_buf)
    end)

    it("counts the first note per type", function()
      assert.truthy(joined:find("note 1", 1, true))
    end)
    it("counts the second note as note 2", function()
      assert.truthy(joined:find("note 2", 1, true))
    end)
    it("labels a warning by type", function()
      assert.truthy(joined:find("warning 1", 1, true))
    end)
    it("labels a tip by type", function()
      assert.truthy(joined:find("tip 1", 1, true))
    end)
  end)

  describe("per-type glyphs and highlights", function()
    local st2
    before_each(function()
      st2 = open(CO, {
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
    end)

    it("uses the note glyph", function()
      assert.truthy(joined_lines(st2.toc_buf):find("N>", 1, true))
    end)
    it("uses the warning glyph", function()
      assert.truthy(joined_lines(st2.toc_buf):find("W>", 1, true))
    end)
    it("uses the tip glyph", function()
      assert.truthy(joined_lines(st2.toc_buf):find("T>", 1, true))
    end)
    it("applies the warning type_hl", function()
      local hls = {}
      local ns = vim.api.nvim_get_namespaces()["toc.nvim"]
      for _, m in ipairs(vim.api.nvim_buf_get_extmarks(st2.toc_buf, ns, 0, -1, { details = true })) do
        hls[tostring(m[4].hl_group)] = true
      end
      assert.is_true(hls["MyWarnHl"] == true)
    end)
  end)
end)

-- ── non-heading label (anchor1 / code1 …) in glyph-only ─────────────────────
describe("render: element labels", function()
  describe("glyph-only", function()
    local joined
    before_each(function()
      local st = open(D, {
        mode = "glyph-only",
        title = false,
        elements = {
          task = { enable = true },
          code = { enable = true },
          callout = { enable = true },
          table = { enable = true },
          image = { enable = true },
          link = { enable = true },
        },
      })
      joined = joined_lines(st.toc_buf)
    end)

    it("carries the language in the code label", function()
      assert.truthy(joined:find("code 1 [lua]", 1, true))
    end)
    it("labels an image 'image 1'", function()
      assert.truthy(joined:find("image 1", 1, true))
    end)
    it("labels a link 'anchor 1'", function()
      assert.truthy(joined:find("anchor 1", 1, true))
    end)
    it("keeps the section number on headings", function()
      assert.truthy(joined:find("1.1", 1, true))
    end)
  end)

  describe("full mode", function()
    local joined
    before_each(function()
      local st = open(D, { mode = "full", title = false, elements = { code = { enable = true } } })
      joined = joined_lines(st.toc_buf)
    end)

    it("shows [lua] once in the code label", function()
      assert.truthy(joined:find("code 1 [lua]", 1, true))
    end)
    it("does not duplicate the lua text", function()
      assert.is_nil(joined:find "%[lua%] lua")
    end)
  end)
end)

-- ── render / glyphs / title ───────────────────────────────────────────────
describe("render: glyphs and title", function()
  local st
  before_each(function()
    st = open(A, { title = "TOC" })
  end)

  it("shows the title", function()
    local lines = vim.api.nvim_buf_get_lines(st.toc_buf, 0, -1, false)
    assert.truthy(lines[1]:find("TOC", 1, true))
  end)
  it("gives a root heading no connector", function()
    local lines = vim.api.nvim_buf_get_lines(st.toc_buf, 0, -1, false)
    assert.is_nil(lines[3]:find("├", 1, true))
    assert.is_nil(lines[3]:find("╰", 1, true))
  end)
  it("gives a nested heading a branch glyph", function()
    local lines = vim.api.nvim_buf_get_lines(st.toc_buf, 0, -1, false)
    assert.truthy(lines[4]:find("├", 1, true) or lines[4]:find("╰", 1, true))
  end)
  it("contains the heading text", function()
    assert.truthy(joined_lines(st.toc_buf):find("Section A", 1, true))
  end)
  it("maps a display line back to source heading 4", function()
    assert.equals(4, st.line_to_heading[st.heading_to_line[4]])
  end)
  it("opens the cursor on the first entry", function()
    assert.equals(st.heading_to_line[1], vim.api.nvim_win_get_cursor(st.toc_win)[1])
  end)
  it("clamps the cursor to the first entry and column 0", function()
    vim.api.nvim_set_current_win(st.toc_win)
    pcall(vim.api.nvim_win_set_cursor, st.toc_win, { 1, 0 })
    vim.api.nvim_exec_autocmds("CursorMoved", { buffer = st.toc_buf })
    assert.equals(st.heading_to_line[1], vim.api.nvim_win_get_cursor(st.toc_win)[1])

    pcall(vim.api.nvim_win_set_cursor, st.toc_win, { st.heading_to_line[2], 3 })
    vim.api.nvim_exec_autocmds("CursorMoved", { buffer = st.toc_buf })
    assert.equals(0, vim.api.nvim_win_get_cursor(st.toc_win)[2])
  end)
end)

-- ── highlight mapping: glyph → heading colour, text → Normal ────────────────
describe("render: highlight mapping", function()
  local first
  before_each(function()
    local st = open(A, { title = false, numbers = false })
    local by_line = {}
    for _, m in ipairs(marks(st.toc_buf, "toc.nvim")) do
      by_line[m[2]] = by_line[m[2]] or {}
      table.insert(by_line[m[2]], m[4].hl_group)
    end
    first = by_line[0] or {}
  end)

  it("uses the per-level heading highlight for the glyph", function()
    assert.is_true(vim.tbl_contains(first, "TocHeading1"))
  end)
  it("uses TocText for the text", function()
    assert.is_true(vim.tbl_contains(first, "TocText"))
  end)
end)

-- ── section numbering ───────────────────────────────────────────────────────
describe("render: numbering", function()
  it("numbers H1 as 1 in nested mode", function()
    local st = open(A, { title = false, numbers = "nested", elements = { heading = { label = "" } } })
    local lines = vim.api.nvim_buf_get_lines(st.toc_buf, 0, -1, false)
    assert.truthy(lines[1]:find(" 1 ", 1, true) or lines[1]:find " 1$")
  end)
  it("numbers a nested child as 1.1", function()
    local st = open(A, { title = false, numbers = "nested", elements = { heading = { label = "" } } })
    assert.truthy(joined_lines(st.toc_buf):find("1.1", 1, true))
  end)
  it("applies the heading label prefix", function()
    local st = open(A, { title = false, numbers = "nested", elements = { heading = { label = "heading" } } })
    assert.truthy(joined_lines(st.toc_buf):find("heading 1.1", 1, true))
  end)
  it("numbers H1 as 1.1 in level mode", function()
    local st = open(A, { title = false, numbers = "level", elements = { heading = { label = "" } } })
    local lines = vim.api.nvim_buf_get_lines(st.toc_buf, 0, -1, false)
    assert.truthy(lines[1]:find("1.1", 1, true))
  end)
  it("numbers an H2 as 2.1 and the second H2 as 2.2 in level mode", function()
    local st = open(A, { title = false, numbers = "level", elements = { heading = { label = "" } } })
    local joined = joined_lines(st.toc_buf)
    assert.truthy(joined:find("2.1", 1, true))
    assert.truthy(joined:find("2.2", 1, true))
  end)
end)

-- ── mode = glyph-only ───────────────────────────────────────────────────────
describe("render: mode = glyph-only", function()
  local st
  before_each(function()
    st = open(A, { mode = "glyph-only", title = false })
  end)

  it("hides the heading text", function()
    assert.is_nil(joined_lines(st.toc_buf):find("Title One", 1, true))
  end)
  it("still shows the number", function()
    assert.truthy(joined_lines(st.toc_buf):find("1.1", 1, true))
  end)
  it("still maps all 5 headings", function()
    assert.equals(5, vim.tbl_count(st.heading_to_line))
  end)
end)

-- ── mode = minimal / text-only ──────────────────────────────────────────────
describe("render: mode variants", function()
  it("minimal hides the number", function()
    local st = open(A, { mode = "minimal", title = false })
    local l1 = vim.api.nvim_buf_get_lines(st.toc_buf, 0, 1, false)[1]
    assert.is_nil(l1:find("1", 1, true))
  end)
  it("text-only shows the text", function()
    local st = open(A, { mode = "text-only", title = false })
    local l1 = vim.api.nvim_buf_get_lines(st.toc_buf, 0, 1, false)[1]
    assert.truthy(l1:find("Title One", 1, true))
  end)
end)

-- ── title = false puts the first heading on line 1 ─────────────────────
describe("render: title = false", function()
  it("puts the first heading on line 1", function()
    local st = open(A, { title = false })
    assert.equals(1, st.heading_to_line[1])
  end)
end)

-- ── width = "auto" fits the longest line ────────────────────────────────────
describe("render: auto width", function()
  it("fits content plus padding", function()
    local st = open(A, { width = "auto", padding = 3, title = false })
    local lines = vim.api.nvim_buf_get_lines(st.toc_buf, 0, -1, false)
    local maxw = 0
    for _, l in ipairs(lines) do
      maxw = math.max(maxw, vim.fn.strdisplaywidth(l))
    end
    local w = vim.api.nvim_win_get_width(st.toc_win)
    assert.is_true(w >= maxw and w <= maxw + 3 + 2 + 1)
  end)
  it("never exceeds width_max", function()
    local st = open(C, { width = "auto", width_max = 24, title = false })
    assert.is_true(vim.api.nvim_win_get_width(st.toc_win) <= 24)
  end)
end)

-- ── truncate to width ───────────────────────────────────────────────────────
describe("render: truncate", function()
  local line
  before_each(function()
    local st = open(C, { width = 20, truncate = true, title = false })
    line = vim.api.nvim_buf_get_lines(st.toc_buf, 0, 1, false)[1]
  end)

  it("fits the panel width", function()
    assert.is_true(vim.fn.strdisplaywidth(line) <= 20 - 2)
  end)
  it("appends an ellipsis", function()
    assert.equals("…", line:sub(-3))
  end)
end)
