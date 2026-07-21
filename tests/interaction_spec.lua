-- toc.nvim interaction / lifecycle behaviour (plenary busted).
local here = debug.getinfo(1, "S").source:sub(2)
local h = dofile(vim.fn.fnamemodify(here, ":h") .. "/helpers.lua")
local toc, view = h.toc, h.view
local open, marks, fixture = h.open, h.marks, h.fixture
local A, B = h.A, h.B

-- ── follow: TOC cursor drives source cursor ─────────────────────────────────
describe("follow: TOC → source", function()
  it("moves the source cursor to the entry line", function()
    local st = open(A, {})
    vim.api.nvim_set_current_win(st.toc_win)
    vim.api.nvim_win_set_cursor(st.toc_win, { st.heading_to_line[4], 0 })
    vim.api.nvim_exec_autocmds("CursorMoved", { buffer = st.toc_buf })
    assert.equals(st.headings[4].lnum, vim.api.nvim_win_get_cursor(st.src_win)[1])
  end)
end)

-- ── reverse follow: source cursor highlights active heading ─────────────────
describe("follow: source → TOC", function()
  it("marks the active heading from the source cursor", function()
    local st = open(A, {})
    vim.api.nvim_set_current_win(st.src_win)
    vim.api.nvim_win_set_cursor(st.src_win, { st.headings[4].lnum, 0 })
    vim.api.nvim_exec_autocmds("CursorMoved", { buffer = st.src_buf })
    local am = marks(st.toc_buf, "toc.nvim.active")
    assert.equals(1, #am)
    assert.equals(st.heading_to_line[4], am[1] and am[1][2] + 1 or -1)
    assert.is_not_nil(am[1] and am[1][4].sign_text)
  end)
end)

-- ── <CR> jumps to source line and focuses the source window ─────────────────
describe("jump: <CR>", function()
  it("focuses the source window at the entry line", function()
    local st = open(A, { focus_on_open = true })
    vim.api.nvim_set_current_win(st.toc_win)
    vim.api.nvim_win_set_cursor(st.toc_win, { st.heading_to_line[4], 0 })
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "x", false)
    assert.equals(st.src_win, vim.api.nvim_get_current_win())
    assert.equals(st.headings[4].lnum, vim.api.nvim_win_get_cursor(st.src_win)[1])
  end)
end)

-- ── beacon flashes then fades ───────────────────────────────────────────────
describe("effects: beacon", function()
  it("flashes in the source then fades away", function()
    local st = open(A, { effects = { beacon = { enable = true, duration = 120, fade_steps = 4 } } })
    vim.api.nvim_set_current_win(st.toc_win)
    vim.api.nvim_win_set_cursor(st.toc_win, { st.heading_to_line[2], 0 })
    vim.api.nvim_exec_autocmds("CursorMoved", { buffer = st.toc_buf })
    assert.equals(1, #marks(st.src_buf, "toc.nvim.beacon"))
    vim.wait(500, function()
      return #marks(st.src_buf, "toc.nvim.beacon") == 0
    end, 20)
    assert.equals(0, #marks(st.src_buf, "toc.nvim.beacon"))
  end)
end)

-- ── buffer switch rebinds TOC to the new markdown buffer ────────────────────
describe("buffer switch", function()
  it("rebinds the TOC to the new markdown buffer", function()
    local st = open(A, {})
    vim.api.nvim_set_current_win(st.src_win)
    vim.cmd("edit " .. vim.fn.fnameescape(B))
    vim.wait(300, function()
      return view.state().src_buf == vim.api.nvim_get_current_buf()
    end, 20)
    local st2 = view.state()
    assert.equals(vim.api.nvim_get_current_buf(), st2.src_buf)
    assert.equals(3, #st2.headings)
    assert.equals("Bravo Doc", st2.headings[1].text)
  end)
end)

-- ── presets ─────────────────────────────────────────────────────────────────
describe("presets", function()
  local function opts()
    return require("toc.config").options
  end

  it("applies a named preset bundle", function()
    open(A, { preset = "minimal" })
    assert.equals("minimal", opts().mode)
    assert.equals(false, opts().title)
  end)
  it("lets user options override the preset", function()
    open(A, { preset = "minimal", mode = "full" })
    assert.equals("full", opts().mode)
  end)
  it("applies an inline table preset", function()
    open(A, { preset = { width = 99 } })
    assert.equals(99, opts().width)
  end)
  it("disables markview-derived glyphs in the plain preset", function()
    open(A, { preset = "plain" })
    assert.equals(false, opts().markview)
    assert.equals("#", opts().glyphs.heading[1])
  end)
end)

-- ── saving re-syncs the TOC even with auto_refresh off ──────────────────────
describe("refresh: on save", function()
  it("re-syncs on BufWritePost even with auto_refresh off", function()
    local st = open(A, { auto_refresh = false })
    local before = #st.headings
    vim.api.nvim_buf_set_lines(st.src_buf, 0, 0, false, { "# Brand New Top", "" })
    vim.api.nvim_exec_autocmds("BufWritePost", { buffer = st.src_buf })
    assert.equals(before + 1, #view.state().headings)
    assert.equals("Brand New Top", view.state().headings[1].text)
  end)
end)

-- ── live refresh debounce ───────────────────────────────────────────────────
describe("refresh: debounce", function()
  it("refreshes immediately with debounce 0", function()
    local st = open(A, { auto_refresh = true, refresh_debounce = 0 })
    local before = #st.headings
    vim.api.nvim_buf_set_lines(st.src_buf, 0, 0, false, { "# Now", "" })
    vim.api.nvim_exec_autocmds("TextChanged", { buffer = st.src_buf })
    assert.equals(before + 1, #view.state().headings)
  end)
  it("eventually fires a debounced refresh", function()
    local st = open(A, { auto_refresh = true, refresh_debounce = 40 })
    local before = #st.headings
    vim.api.nvim_buf_set_lines(st.src_buf, 0, 0, false, { "# Later", "" })
    vim.api.nvim_exec_autocmds("TextChanged", { buffer = st.src_buf })
    vim.wait(300, function()
      return #view.state().headings == before + 1
    end, 10)
    assert.equals(before + 1, #view.state().headings)
  end)
end)

-- ── health check runs without error ─────────────────────────────────────────
describe("health", function()
  it("is callable without error", function()
    assert.is_true(pcall(require("toc.health").check))
  end)
end)

-- ── auto_close hides the TOC when switching to a non-markdown file ──────────
describe("auto_close", function()
  it("closes the TOC on a non-markdown file", function()
    local L = fixture("x.lua", { "local x = 1", "return x" })
    local st = open(A, {})
    assert.is_true(view.is_open())
    vim.api.nvim_set_current_win(st.src_win)
    vim.cmd("edit " .. vim.fn.fnameescape(L))
    vim.wait(300, function()
      return not view.is_open()
    end, 10)
    assert.is_false(view.is_open())
  end)
end)

-- ── auto_enabled opens TOC on markdown filetype ─────────────────────────────
describe("auto_enabled", function()
  it("auto-opens on a markdown filetype", function()
    view.close()
    toc.setup { auto_enabled = true }
    vim.cmd "silent! %bwipeout!"
    vim.cmd("edit " .. vim.fn.fnameescape(A))
    vim.wait(500, function()
      return view.is_open()
    end, 20)
    assert.is_true(view.is_open())
    view.close()
  end)
  it("auto-opens on an HTML file", function()
    view.close()
    toc.setup { auto_enabled = true }
    local H = fixture("auto.html", { "<h1>Title</h1>", "<h2>Sub</h2>" })
    vim.cmd "silent! %bwipeout!"
    vim.cmd("edit " .. vim.fn.fnameescape(H))
    vim.wait(500, function()
      return view.is_open()
    end, 20)
    assert.is_true(view.is_open())
    view.close()
  end)
end)

-- ── toggle / close ──────────────────────────────────────────────────────────
describe("toggle / close", function()
  it("toggles the panel open and closed", function()
    open(A, {})
    assert.is_true(view.is_open())
    toc.toggle()
    assert.is_false(view.is_open())
    toc.toggle()
    assert.is_true(view.is_open())
    toc.close()
    assert.is_false(view.is_open())
  end)
end)
