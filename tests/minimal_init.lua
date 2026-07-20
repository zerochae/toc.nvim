-- Minimal environment for running the toc.nvim test suite.
--   nvim --headless -u tests/minimal_init.lua -c "luafile tests/toc_spec.lua"
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.runtimepath:prepend(root)

vim.o.termguicolors = true
vim.o.swapfile = false
vim.o.hidden = true
vim.cmd "filetype on"

-- Deterministic colours so the beacon fade maths is reproducible.
vim.api.nvim_set_hl(0, "Normal", { bg = "#1e1e28" })
vim.api.nvim_set_hl(0, "IncSearch", { bg = "#f0c85a" })
vim.api.nvim_set_hl(0, "CursorLine", { bg = "#2a2a3a" })
