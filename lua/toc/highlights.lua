local M = {}

-- Default links mirror markview's heading palette when present, otherwise
-- degrade to core groups so colours are always sensible.
local defaults = {
  TocHeading1 = { link = "MarkviewHeading1", fallback = "@markup.heading.1.markdown" },
  TocHeading2 = { link = "MarkviewHeading2", fallback = "@markup.heading.2.markdown" },
  TocHeading3 = { link = "MarkviewHeading3", fallback = "@markup.heading.3.markdown" },
  TocHeading4 = { link = "MarkviewHeading4", fallback = "@markup.heading.4.markdown" },
  TocHeading5 = { link = "MarkviewHeading5", fallback = "@markup.heading.5.markdown" },
  TocHeading6 = { link = "MarkviewHeading6", fallback = "@markup.heading.6.markdown" },
  TocTitle = { link = "Title", fallback = "Title" },
  TocGuide = { link = "Comment", fallback = "Comment", plain = true },
  TocText = { link = "Normal", fallback = "Normal" },
  TocNumber = { link = "Normal", fallback = "Normal" },
  TocCursor = { link = "Visual", fallback = "Visual" },
  TocBeacon = { link = "IncSearch", fallback = "Search" },
  TocActiveSign = { link = "MarkviewHeading1Sign", fallback = "Special" },
  TocActiveLine = { link = "CursorLine", fallback = "CursorLine" },
  -- element kinds
  TocTask = { link = "MarkviewCheckboxUnchecked", fallback = "Todo" },
  TocTaskDone = { link = "MarkviewCheckboxChecked", fallback = "String" },
  TocCode = { link = "MarkviewInlineCode", fallback = "Function" },
  TocCallout = { link = "MarkviewBlockQuoteNote", fallback = "Special" },
  TocTable = { link = "MarkviewTableHeader", fallback = "Type" },
  TocImage = { link = "MarkviewImage", fallback = "Directory" },
  TocLink = { link = "MarkviewHyperlink", fallback = "Underlined" },
  TocBullet = { link = "MarkviewListItemStar", fallback = "Special" },
  TocSummary = { link = "MarkviewHeading4", fallback = "Title" },
  TocDefinition = { link = "MarkviewListItemPlus", fallback = "Identifier" },
}

---@param name string
---@return boolean
local function hl_exists(name)
  local ok, def = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
  return ok and def ~= nil and not vim.tbl_isempty(def)
end

function M.setup()
  for group, spec in pairs(defaults) do
    local target = hl_exists(spec.link) and spec.link or spec.fallback
    if spec.plain then
      -- Copy only the foreground colour; drop italic/bold/underline styles.
      local def = vim.api.nvim_get_hl(0, { name = target, link = false })
      vim.api.nvim_set_hl(0, group, { fg = def and def.fg or nil, default = true })
    else
      vim.api.nvim_set_hl(0, group, { link = target, default = true })
    end
  end
end

return M
