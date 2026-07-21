local M = {}

local h = vim.health

function M.check()
  h.start "toc.nvim"

  if vim.fn.has "nvim-0.10" == 1 then
    h.ok("Neovim " .. tostring(vim.version()))
  else
    h.error "Neovim 0.10+ is required"
  end

  if vim.o.termguicolors then
    h.ok "termguicolors is enabled"
  else
    h.warn("termguicolors is off", "highlights may look washed out; `:set termguicolors`")
  end

  local ok, config = pcall(require, "toc.config")
  if ok and type(config.options) == "table" then
    h.ok("configuration loaded (mode = " .. tostring(config.options.mode) .. ")")
  else
    h.error "failed to load toc.config"
  end

  local enabled = {}
  for kind, spec in pairs((config and config.options.elements) or {}) do
    if spec.enable then
      enabled[#enabled + 1] = kind
    end
  end
  table.sort(enabled)
  h.info("indexed elements: " .. (next(enabled) and table.concat(enabled, ", ") or "none"))

  if pcall(require, "nvim-web-devicons") then
    h.ok "nvim-web-devicons found (code language icons enabled)"
  else
    h.info "nvim-web-devicons not found (optional; enables code language icons)"
  end

  if pcall(require, "markview") then
    h.ok "markview.nvim found (borrowing glyphs/colours when enabled)"
  else
    h.info "markview.nvim not found (optional; borrows heading/checkbox glyphs)"
  end

  h.info "glyphs require a Nerd Font (v3+). If you see boxes, install one and set 'guifont'."
  h.info "markdown/help parsing is regex-based (no treesitter needed)."
  h.info "HTML parsing uses treesitter when available, with a limited regex fallback."
end

return M
