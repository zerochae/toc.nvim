-- toc.nvim config validation behaviour (plenary busted).
local here = debug.getinfo(1, "S").source:sub(2)
local h = dofile(vim.fn.fnamemodify(here, ":h") .. "/helpers.lua")
local toc = h.toc
local config = require "toc.config"

-- Run `fn` with vim.notify captured; returns the list of {msg, level}.
local function capture_warnings(fn)
  local orig = vim.notify
  local msgs = {}
  vim.notify = function(msg, level)
    msgs[#msgs + 1] = { msg = msg, level = level }
  end
  pcall(fn)
  vim.notify = orig
  return msgs
end

local function matching(msgs, needle)
  return vim.tbl_filter(function(m)
    return type(m.msg) == "string" and m.msg:find(needle, 1, true) ~= nil
  end, msgs)
end

describe("config validation", function()
  it("warns on an unknown preset name and falls back to defaults", function()
    local msgs = capture_warnings(function()
      toc.setup { auto_enabled = false, preset = "does-not-exist" }
    end)
    assert.is_true(#matching(msgs, "unknown preset") >= 1)
    assert.equals("full", config.options.mode)
  end)

  it("warns on a preset of the wrong type", function()
    local msgs = capture_warnings(function()
      toc.setup { auto_enabled = false, preset = 42 }
    end)
    assert.is_true(#matching(msgs, "preset") >= 1)
  end)

  it("warns on an invalid mode", function()
    local msgs = capture_warnings(function()
      toc.setup { auto_enabled = false, mode = "bogus" }
    end)
    assert.is_true(#matching(msgs, "invalid mode") >= 1)
  end)

  it("warns on an invalid position", function()
    local msgs = capture_warnings(function()
      toc.setup { auto_enabled = false, position = "top" }
    end)
    assert.is_true(#matching(msgs, "invalid position") >= 1)
  end)

  it("warns on invalid numbers but accepts false", function()
    local bad = capture_warnings(function()
      toc.setup { auto_enabled = false, numbers = "roman" }
    end)
    assert.is_true(#matching(bad, "invalid numbers") >= 1)

    local ok = capture_warnings(function()
      toc.setup { auto_enabled = false, numbers = false }
    end)
    assert.equals(0, #matching(ok, "invalid numbers"))
  end)

  it("warns on an invalid width", function()
    local msgs = capture_warnings(function()
      toc.setup { auto_enabled = false, width = true }
    end)
    assert.is_true(#matching(msgs, "invalid width") >= 1)
  end)

  it("warns on an out-of-range max_level but accepts 1-6", function()
    local bad = capture_warnings(function()
      toc.setup { auto_enabled = false, max_level = 9 }
    end)
    assert.is_true(#matching(bad, "invalid max_level") >= 1)

    local ok = capture_warnings(function()
      toc.setup { auto_enabled = false, max_level = 3 }
    end)
    assert.equals(0, #matching(ok, "invalid max_level"))
  end)

  it("warns when setup is not given a table", function()
    local msgs = capture_warnings(function()
      toc.setup "nope"
    end)
    assert.is_true(#matching(msgs, "expects a table") >= 1)
  end)

  it("accepts a valid preset without warning", function()
    local msgs = capture_warnings(function()
      toc.setup { auto_enabled = false, preset = "minimal" }
    end)
    assert.equals(0, #msgs)
    assert.equals("minimal", config.options.mode)
  end)
end)
