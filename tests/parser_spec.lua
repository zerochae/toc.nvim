-- toc.nvim parser behaviour (plenary busted).
local here = debug.getinfo(1, "S").source:sub(2)
local h = dofile(vim.fn.fnamemodify(here, ":h") .. "/helpers.lua")
local toc, parser = h.toc, h.parser
local fixture, kind_counts, first_by_kind = h.fixture, h.kind_counts, h.first_by_kind
local HEADINGS_ONLY, A, D = h.HEADINGS_ONLY, h.A, h.D

-- ── parser (headings only) ──────────────────────────────────────────────────
describe("parser (headings only)", function()
  local entries
  before_each(function()
    toc.setup { auto_enabled = false, elements = vim.deepcopy(HEADINGS_ONLY) }
    vim.cmd("edit " .. vim.fn.fnameescape(A))
    entries = parser.parse(0)
  end)

  it("counts headings, skipping fenced code", function()
    assert.equals(5, #entries)
  end)
  it("strips # from the first heading text", function()
    assert.equals("Title One", entries[1].text)
  end)
  it("tags the first entry as a heading", function()
    assert.equals("heading", entries[1].kind)
  end)
  it("records the first heading level", function()
    assert.equals(1, entries[1].level)
  end)
  it("records a nested heading level", function()
    assert.equals(3, entries[3].level)
  end)
  it("detects a setext heading", function()
    assert.equals("Setext One", entries[5].text)
  end)
  it("levels a setext === heading as 1", function()
    assert.equals(1, entries[5].level)
  end)
  it("records the heading line number", function()
    assert.equals(10, entries[4].lnum)
  end)
end)

-- ── parser: front matter ────────────────────────────────────────────────────
describe("parser: front matter", function()
  it("skips a leading YAML (---) front matter block", function()
    local F = fixture("fm-yaml.md", {
      "---",
      "title: Doc",
      "see: [x](http://y)",
      "---",
      "# Real Heading",
    })
    toc.setup { auto_enabled = false, elements = { heading = { enable = true }, link = { enable = true } } }
    vim.cmd("edit " .. vim.fn.fnameescape(F))
    local entries = parser.parse(0)
    assert.equals(0, kind_counts(entries).link or 0)
    assert.equals(1, kind_counts(entries).heading)
    assert.equals("Real Heading", entries[1].text)
  end)

  it("skips a leading TOML (+++) front matter block", function()
    local F = fixture("fm-toml.md", {
      "+++",
      'title = "Doc"',
      "+++",
      "# Real Heading",
    })
    toc.setup { auto_enabled = false, elements = vim.deepcopy(HEADINGS_ONLY) }
    vim.cmd("edit " .. vim.fn.fnameescape(F))
    local entries = parser.parse(0)
    assert.equals(1, #entries)
    assert.equals("Real Heading", entries[1].text)
  end)

  it("leaves an unclosed --- alone (no front matter)", function()
    local F = fixture("fm-open.md", {
      "---",
      "# Still A Heading",
    })
    toc.setup { auto_enabled = false, elements = vim.deepcopy(HEADINGS_ONLY) }
    vim.cmd("edit " .. vim.fn.fnameescape(F))
    local entries = parser.parse(0)
    assert.equals("Still A Heading", entries[1].text)
  end)

  it("does not treat a setext H2 rule as front matter", function()
    local F = fixture("fm-setext.md", {
      "Title Line",
      "---",
      "## Sub",
    })
    toc.setup { auto_enabled = false, elements = vim.deepcopy(HEADINGS_ONLY) }
    vim.cmd("edit " .. vim.fn.fnameescape(F))
    local entries = parser.parse(0)
    assert.equals("Title Line", entries[1].text)
    assert.equals(2, entries[1].level)
  end)
end)

-- ── parser: nested fences (4-backtick wrapping 3-backtick) ──────────────────
describe("parser: nested fences", function()
  local entries
  before_each(function()
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
    entries = parser.parse(0)
  end)

  it("does not treat an inner fenced # as a heading", function()
    assert.equals(2, #entries)
  end)
  it("finds the heading after the outer fence", function()
    assert.equals("After Fence", entries[2].text)
  end)
end)

-- ── a bullet containing a link yields both a bullet and an anchor ───────────
describe("parser: bullet + link", function()
  local by_kind
  before_each(function()
    local BL = fixture("bl.md", {
      "# Doc",
      "- see [markview](https://x) here",
    })
    toc.setup { auto_enabled = false, elements = { link = { enable = true }, bullet = { enable = true } } }
    vim.cmd("edit " .. vim.fn.fnameescape(BL))
    by_kind = first_by_kind(parser.parse(0))
  end)

  it("extracts the inline link as an anchor", function()
    assert.equals("markview", by_kind.link.text)
  end)
  it("still emits the bullet", function()
    assert.equals("see markview here", by_kind.bullet.text)
  end)
  it("nests the anchor one level under the bullet", function()
    assert.equals(by_kind.bullet.level + 1, by_kind.link.level)
  end)
end)

-- ── parser dispatches on filetype: Vim help sections ───────────────────────
describe("parser: Vim help sections", function()
  local entries
  before_each(function()
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
    entries = parser.parse(0)
  end)

  it("counts help sections", function()
    assert.equals(3, #entries)
  end)
  it("strips the tag from a level-1 section", function()
    assert.equals("SECTION ONE", entries[1].text)
  end)
  it("levels a top section as 1", function()
    assert.equals(1, entries[1].level)
  end)
  it("levels a subsection as 2", function()
    assert.equals(2, entries[2].level)
  end)
  it("reads the subsection text", function()
    assert.equals("1.1 Subsection", entries[2].text)
  end)
  it("reads the second section", function()
    assert.equals("SECTION TWO", entries[3].text)
  end)
end)

-- ── help extras: ~ subheadings, tags, code, callouts ────────────────────────
describe("parser: help elements", function()
  local counts
  before_each(function()
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
    counts = kind_counts(parser.parse(0))
  end)

  it("indexes the section and ~ subheading", function()
    assert.equals(2, counts.heading)
  end)
  it("indexes the code block", function()
    assert.equals(1, counts.code)
  end)
  it("indexes the Note callout", function()
    assert.equals(1, counts.callout)
  end)
  it("indexes a body tag as an anchor", function()
    assert.equals(1, counts.link)
  end)
end)

-- ── parser: raw HTML headings ───────────────────────────────────────────────
describe("parser: raw HTML headings", function()
  local entries
  before_each(function()
    local E = fixture("e.md", {
      "# Markdown H1",
      '<h2 id="sec">HTML Section</h2>',
      "<h3>Sub</h3>",
    })
    toc.setup { auto_enabled = false, elements = vim.deepcopy(HEADINGS_ONLY) }
    vim.cmd("edit " .. vim.fn.fnameescape(E))
    entries = parser.parse(0)
  end)

  it("counts markdown and HTML headings together", function()
    assert.equals(3, #entries)
  end)
  it("reads the HTML h2 level", function()
    assert.equals(2, entries[2].level)
  end)
  it("strips tags/attrs from HTML heading text", function()
    assert.equals("HTML Section", entries[2].text)
  end)
  it("reads the HTML h3 level", function()
    assert.equals(3, entries[3].level)
  end)
end)

-- ── parser: inline HTML in markdown shares the html scanner ─────────────────
describe("parser: inline HTML in markdown", function()
  local counts
  before_each(function()
    local E = fixture("inline.md", {
      "# Title",
      '<p>see <a href="u">the guide</a></p>',
      '<img alt="diagram" src="d/e.png">',
    })
    toc.setup { auto_enabled = false, elements = { link = { enable = true }, image = { enable = true } } }
    vim.cmd("edit " .. vim.fn.fnameescape(E))
    counts = kind_counts(parser.parse(0))
  end)

  it("parses an inline <a> link", function()
    assert.equals(1, counts.link or 0)
  end)
  it("parses an inline <img> image", function()
    assert.equals(1, counts.image or 0)
  end)
end)

-- ── parser: markdown-embedded HTML headings are cleaned of markdown syntax ───
describe("parser: HTML heading cleaning", function()
  local entries
  before_each(function()
    local E = fixture("clean.md", {
      "<h2>Hello **world** and `code`</h2>",
      "<h3>[Link](url)</h3>",
    })
    toc.setup { auto_enabled = false, elements = vim.deepcopy(HEADINGS_ONLY) }
    vim.cmd("edit " .. vim.fn.fnameescape(E))
    entries = parser.parse(0)
  end)

  it("strips markdown emphasis from an HTML heading", function()
    assert.equals("Hello world and code", entries[1].text)
  end)
  it("strips a markdown link from an HTML heading", function()
    assert.equals("Link", entries[2].text)
  end)
end)

-- ── parser: HTML table cell content does not leak as separate entries ────────
describe("parser: HTML table no leak", function()
  local counts
  before_each(function()
    local E = fixture("leak.md", {
      "# Title",
      "<table>",
      "  <caption>Refs</caption>",
      '  <tr><td><a href="u">cell link</a></td></tr>',
      "</table>",
      "after",
    })
    toc.setup { auto_enabled = false, elements = { table = { enable = true }, link = { enable = true } } }
    vim.cmd("edit " .. vim.fn.fnameescape(E))
    counts = kind_counts(parser.parse(0))
  end)

  it("emits one table entry", function()
    assert.equals(1, counts.table)
  end)
  it("does not leak a link from a table cell", function()
    assert.equals(0, counts.link or 0)
  end)
end)

-- ── parser: an unclosed HTML <table> is consumed to end-of-buffer ───────────
describe("parser: unclosed HTML table", function()
  local counts, by_kind
  before_each(function()
    local E = fixture("unclosed.md", {
      "# Title",
      "<table>",
      "  <caption>Broken</caption>",
      '  <tr><td><a href="u">leaked</a></td></tr>',
      "  <tr><td>more cells</td></tr>",
    })
    toc.setup { auto_enabled = false, elements = { table = { enable = true }, link = { enable = true } } }
    vim.cmd("edit " .. vim.fn.fnameescape(E))
    local entries = parser.parse(0)
    counts = kind_counts(entries)
    by_kind = first_by_kind(entries)
  end)

  it("emits one table entry", function()
    assert.equals(1, counts.table)
  end)
  it("does not leak links from unclosed table cells", function()
    assert.equals(0, counts.link or 0)
  end)
  it("still derives the caption label", function()
    assert.equals("Broken", by_kind.table.text)
  end)
end)

-- ── parser: multiline inline HTML in markdown (details, table, dl) ───────────
describe("parser: HTML blocks in markdown", function()
  local by_kind
  before_each(function()
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
    toc.setup {
      auto_enabled = false,
      elements = { summary = { enable = true }, table = { enable = true }, definition = { enable = true } },
    }
    vim.cmd("edit " .. vim.fn.fnameescape(E))
    by_kind = first_by_kind(parser.parse(0))
  end)

  it("parses an inline <summary>", function()
    assert.equals("Expand me", by_kind.summary and by_kind.summary.text)
  end)
  it("parses a multiline <table> caption", function()
    assert.equals("Scores", by_kind.table and by_kind.table.text)
  end)
  it("parses an inline <dt>", function()
    assert.equals("Term", by_kind.definition and by_kind.definition.text)
  end)
end)

-- ── parser dispatches on filetype: HTML (regex fallback path) ───────────────
describe("parser: HTML filetype", function()
  local entries, counts
  before_each(function()
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
    entries = parser.parse(0)
    counts = kind_counts(entries)
  end)

  it("parses h1/h2 headings", function()
    assert.equals(2, counts.heading)
  end)
  it("parses an <a> link", function()
    assert.equals(1, counts.link)
  end)
  it("parses an <img> image", function()
    assert.equals(1, counts.image)
  end)
  it("reads the first heading text", function()
    assert.equals("Title", entries[1].text)
  end)
end)

-- ── parser: HTML details/summary, table, definition list ────────────────────
describe("parser: HTML rich elements", function()
  local by_kind
  before_each(function()
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
    toc.setup {
      auto_enabled = false,
      elements = { summary = { enable = true }, table = { enable = true }, definition = { enable = true } },
    }
    vim.cmd("edit " .. vim.fn.fnameescape(H))
    vim.bo.filetype = "html"
    by_kind = first_by_kind(parser.parse(0))
  end)

  it("parses a <summary>", function()
    assert.is_not_nil(by_kind.summary)
    assert.equals("Advanced options", by_kind.summary.text)
  end)
  it("parses a <table> using its caption", function()
    assert.is_not_nil(by_kind.table)
    assert.equals("Feature matrix", by_kind.table.text)
  end)
  it("parses a <dt> definition term", function()
    assert.is_not_nil(by_kind.definition)
    assert.equals("TOC", by_kind.definition.text)
  end)
end)

-- ── parser: HTML regex fallback (no treesitter) ─────────────────────────────
describe("parser: HTML regex fallback", function()
  local entries
  before_each(function()
    local H = fixture("fallback.html", {
      "<h1>Doc</h1>",
      "<table>",
      "  <caption>Feature matrix</caption>",
      '  <tr><td><a href="u">cell</a></td></tr>',
      "</table>",
    })
    toc.setup { auto_enabled = false, elements = { table = { enable = true }, link = { enable = true } } }
    vim.cmd("edit " .. vim.fn.fnameescape(H))
    vim.bo.filetype = "html"
    -- Exercise the fallback directly, regardless of whether a treesitter
    -- HTML parser is installed in this environment.
    local Html = require "toc.parsers.html"
    local p = Html.new(0)
    p:regex()
    entries = p.entries
  end)

  it("parses the heading", function()
    assert.equals("Doc", entries[1].text)
  end)
  it("parses a <table> via the fallback, labelled by caption", function()
    local counts = kind_counts(entries)
    assert.equals(1, counts.table)
    assert.equals("Feature matrix", first_by_kind(entries).table.text)
  end)
  it("does not leak links from consumed table cells", function()
    assert.equals(0, kind_counts(entries).link or 0)
  end)

  it("parses pre/blockquote/li via the fallback", function()
    local H = fixture("fallback2.html", {
      "<h1>Doc</h1>",
      "<pre>print(1)</pre>",
      "<blockquote>Important note</blockquote>",
      "<ul><li>First item</li></ul>",
    })
    toc.setup {
      auto_enabled = false,
      elements = { code = { enable = true }, callout = { enable = true }, bullet = { enable = true } },
    }
    vim.cmd("edit " .. vim.fn.fnameescape(H))
    vim.bo.filetype = "html"
    local Html = require "toc.parsers.html"
    local p = Html.new(0)
    p:regex()
    local counts = kind_counts(p.entries)
    assert.equals(1, counts.code or 0)
    assert.equals(1, counts.callout or 0)
    assert.equals(1, counts.bullet or 0)
    assert.equals("Important note", first_by_kind(p.entries).callout.text)
  end)
end)

-- ── parser: typed elements ──────────────────────────────────────────────────
describe("parser: typed elements", function()
  local entries
  before_each(function()
    toc.setup {
      auto_enabled = false,
      elements = {
        task = { enable = true },
        code = { enable = true },
        callout = { enable = true },
        table = { enable = true },
        image = { enable = true },
        link = { enable = true },
      },
    }
    vim.cmd("edit " .. vim.fn.fnameescape(D))
    entries = parser.parse(0)
  end)

  it("parses task entries", function()
    assert.equals(2, kind_counts(entries).task or 0)
  end)
  it("parses a code entry", function()
    assert.equals(1, kind_counts(entries).code or 0)
  end)
  it("parses a callout entry", function()
    assert.equals(1, kind_counts(entries).callout or 0)
  end)
  it("parses a table entry", function()
    assert.equals(1, kind_counts(entries).table or 0)
  end)
  it("parses an image entry", function()
    assert.equals(1, kind_counts(entries).image or 0)
  end)
  it("parses at least one link entry", function()
    assert.is_true((kind_counts(entries).link or 0) >= 1)
  end)
  it("carries the code language", function()
    assert.equals("lua", first_by_kind(entries).code.text)
  end)
  it("captures the task done state", function()
    assert.is_true(entries[4].done == true)
  end)
end)
