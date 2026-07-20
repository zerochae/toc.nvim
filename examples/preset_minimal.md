# Preset: minimal

Bare glyph tree — no numbers, labels, title or text.

Rendered for [demo2.md](./demo2.md). Variations show how `labels` / `numbers`
change the output on top of this preset (identical variations are omitted).

## Base

```lua
require("toc").setup {
  preset = "minimal",
}
```

```
󰌕
├╴󰌖
│ ├╴󰼑
│ ╰╴󰼑
├╴󰌖
│ ├╴󰼑
│ ├╴󰼑
│ │ ╰╴
│ ╰╴󰼑
│   ├╴
│   ╰╴󰋽
├╴󰌖
│ ├╴
│ ╰╴
├╴󰌖
│ ├╴󰼑
│ ╰╴󰼑
│   ├╴󰎲
│   ╰╴󰎲
│     ╰╴
├╴󰌖
│ ├╴󰗠
│ ├╴󰗠
│ ├╴󰄰
│ ╰╴󰄰
│   ├╴󰄰
│   ╰╴󰄰
├╴󰌖
╰╴󰌖
```
