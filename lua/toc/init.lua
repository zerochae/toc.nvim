local config = require "toc.config"
local highlights = require "toc.highlights"
local view = require "toc.view"

local M = {}

---@param opts? toc.Config partial configuration, deep-merged over the defaults
function M.setup(opts)
  config.setup(opts)
  highlights.setup()

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("toc.nvim.colors", { clear = true }),
    callback = highlights.setup,
  })

  local group = vim.api.nvim_create_augroup("toc.nvim.auto", { clear = true })
  if config.options.auto_enabled then
    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      pattern = config.options.filetypes,
      callback = function(args)
        if vim.bo[args.buf].buftype ~= "" or view.is_open() then
          return
        end
        vim.schedule(function()
          if vim.api.nvim_get_current_buf() == args.buf and not view.is_open() then
            view.open()
          end
        end)
      end,
    })
  end
end

M.open = view.open
M.close = view.close
M.toggle = view.toggle
M.refresh = view.refresh
M.is_open = view.is_open

return M
