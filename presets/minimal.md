# Preset: minimal

Bare glyph tree — no numbers, labels, title or text.

Rendered for the *Widget Service* section of [demo.md](../tests/fixtures/demo.md).
Variations show how `labels` / `numbers` change the output on top of this
preset (identical variations are omitted).

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
