---@meta
-- Type definitions for toc.nvim. Loaded by lua-language-server for completion
-- and type checking; never required at runtime.

---@class toc.Element
---@field enable boolean whether this kind is indexed
---@field label? string label prefix shown before the index ("" = number only)
---@field glyph? string icon for non-heading kinds
---@field types? table<string, string> callout: per-type glyph keyed by lowercased type
---@field type_hls? table<string, string> callout: per-type highlight group keyed by lowercased type
---@field done? string task: checked glyph
---@field todo? string task: unchecked glyph
---@field states? table<string, string> task: per-state glyph keyed by the char in [ ]
---@field state_hls? table<string, string> task: per-state highlight group keyed by the char in [ ]
---@field lang_glyph? boolean code: prefix the language with a devicons icon

---@class toc.Elements
---@field heading toc.Element
---@field task toc.Element
---@field code toc.Element
---@field callout toc.Element
---@field table toc.Element
---@field image toc.Element
---@field link toc.Element
---@field bullet toc.Element

---@class toc.Glyphs
---@field heading string[] per-level heading icons (index 1-6)
---@field fallback string icon for entries with no kind-specific glyph
---@field branch string tree connector for a non-last child
---@field last string tree connector for the last child
---@field vertical string vertical guide for ancestor columns

---@class toc.Beacon
---@field enable boolean
---@field hl string highlight group used as the flash colour
---@field duration integer total fade time in ms
---@field fade_steps integer number of fade frames

---@class toc.ActiveSign
---@field enable boolean
---@field text string sign text drawn beside the active entry
---@field hl string

---@class toc.ActiveLine
---@field enable boolean
---@field hl string

---@class toc.Effects
---@field beacon toc.Beacon
---@field active_sign toc.ActiveSign
---@field active_line toc.ActiveLine

---@class toc.Keymaps
---@field jump? string jump to entry and focus the source
---@field jump_stay? string jump but keep focus in the TOC
---@field close? string
---@field refresh? string
---@field next? string
---@field prev? string

---@class toc.Config
---@field width integer|"auto" fixed column count, or "auto" to fit the longest line
---@field padding integer extra columns beside the content when width = "auto"
---@field width_max integer upper bound for the auto width
---@field position "right"|"left"
---@field follow_cursor boolean TOC movement drives the source cursor
---@field follow_source boolean source movement marks the active entry
---@field focus_on_open boolean focus the TOC when it opens
---@field close_on_select boolean close the TOC after <CR>
---@field auto_refresh boolean live-update as the buffer changes
---@field refresh_debounce integer ms of quiet before a live refresh (0 = instant)
---@field preset? string|table named preset ("compact"|"boxed"|"minimal"|"writing"|"plain") or inline bundle
---@field markview boolean borrow heading/checkbox glyphs from markview.nvim when available
---@field auto_enabled boolean auto-open on a matching buffer
---@field filetypes string[]
---@field mode "full"|"glyph-only"|"text-only"|"minimal"
---@field numbers "level"|"nested"|"flat"|false
---@field labels boolean show label prefixes ("heading", "anchor", …); false = numbers/indices only
---@field truncate boolean clip overflow with an ellipsis
---@field indent integer per-depth indent when guides = false
---@field guides boolean draw tree guide lines
---@field title string|false header text; false hides it
---@field elements toc.Elements
---@field glyphs toc.Glyphs
---@field highlights string[] highlight group per heading level
---@field effects toc.Effects
---@field window table<string, any> window-local options for the panel
---@field keymaps toc.Keymaps

---@class TocEntry
---@field lnum integer 1-based line in the source buffer
---@field level integer tree depth level
---@field kind "heading"|"task"|"code"|"callout"|"table"|"image"|"link"|"bullet"
---@field text string cleaned label
---@field done? boolean task completion state
---@field state? string task: raw char inside [ ] ("x", " ", "/", …)
---@field label? string per-instance label prefix (e.g. callout type)
