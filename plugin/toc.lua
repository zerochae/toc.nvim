if vim.g.loaded_toc then
  return
end
vim.g.loaded_toc = true

vim.api.nvim_create_user_command("Toc", function(opts)
  local toc = require "toc"
  local action = opts.args ~= "" and opts.args or "toggle"
  local fn = toc[action]
  if type(fn) == "function" then
    fn()
  else
    vim.notify("toc.nvim: unknown action '" .. action .. "'", vim.log.levels.ERROR)
  end
end, {
  nargs = "?",
  complete = function()
    return { "toggle", "open", "close", "refresh" }
  end,
  desc = "Table of contents (toggle|open|close|refresh)",
})
