-- Minimal environment for the toc.nvim plenary test suite.
--   nvim --headless --noplugin -u tests/minimal_init.lua \
--     -c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal_init.lua' }"
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.runtimepath:prepend(root)

-- Locate plenary.nvim from the CI checkout or a local plugin manager.
local plenary_candidates = {
  root .. "/.tests/plenary.nvim",
  vim.fn.stdpath "data" .. "/lazy/plenary.nvim",
  vim.fn.stdpath "data" .. "/site/pack/vendor/start/plenary.nvim",
}
for _, path in ipairs(plenary_candidates) do
  if vim.fn.isdirectory(path) == 1 then
    vim.opt.runtimepath:prepend(path)
    break
  end
end

vim.o.termguicolors = true
vim.o.swapfile = false
vim.o.hidden = true
vim.cmd "filetype on"

-- Deterministic colours so the beacon fade maths is reproducible.
vim.api.nvim_set_hl(0, "Normal", { bg = "#1e1e28" })
vim.api.nvim_set_hl(0, "IncSearch", { bg = "#f0c85a" })
vim.api.nvim_set_hl(0, "CursorLine", { bg = "#2a2a3a" })

-- --noplugin skips plenary's plugin/, which defines PlenaryBustedDirectory;
-- load it (and the busted globals) explicitly.
require "plenary.busted"
vim.cmd "runtime plugin/plenary.vim"
