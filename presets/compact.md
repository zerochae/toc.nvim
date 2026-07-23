# Preset: compact

Narrow panel, glyph + label/number, text hidden.

Rendered for the *Widget Service* section of [demo.md](../tests/fixtures/demo.md).
Variations show how `labels` / `numbers` change the output on top of this
preset (identical variations are omitted).

## Base

```lua
require("toc").setup {
  preset = "compact",
}
```

```
󰌕 heading 1.1
├╴󰌖 heading 2.1
│ ├╴󰼑 heading 3.1
│ ╰╴󰼑 heading 3.2
├╴󰌖 heading 2.2
│ ├╴󰼑 heading 3.3
│ ├╴󰼑 heading 3.4
│ │ ╰╴ code 1 [ sh]
│ ╰╴󰼑 heading 3.5
│   ├╴ code 2 [ sh]
│   ╰╴󰋽 note 1
├╴󰌖 heading 2.3
│ ├╴ table 1
│ ╰╴ warning 1
├╴󰌖 heading 2.4
│ ├╴󰼑 heading 3.6
│ ╰╴󰼑 heading 3.7
│   ├╴󰎲 heading 4.1
│   ╰╴󰎲 heading 4.2
│     ╰╴ tip 1
├╴󰌖 heading 2.5
│ ├╴󰗠 task 1
│ ├╴󰗠 task 2
│ ├╴󰄰 task 3
│ ╰╴󰄰 task 4
│   ├╴󰄰 task 5
│   ╰╴󰄰 task 6
├╴󰌖 heading 2.6
╰╴󰌖 heading 2.7
```

## labels = false

```lua
require("toc").setup {
  preset = "compact",
  labels = false,
}
```

```
󰌕 1.1
├╴󰌖 2.1
│ ├╴󰼑 3.1
│ ╰╴󰼑 3.2
├╴󰌖 2.2
│ ├╴󰼑 3.3
│ ├╴󰼑 3.4
│ │ ╰╴ 1 [ sh]
│ ╰╴󰼑 3.5
│   ├╴ 2 [ sh]
│   ╰╴󰋽 1
├╴󰌖 2.3
│ ├╴ 1
│ ╰╴ 1
├╴󰌖 2.4
│ ├╴󰼑 3.6
│ ╰╴󰼑 3.7
│   ├╴󰎲 4.1
│   ╰╴󰎲 4.2
│     ╰╴ 1
├╴󰌖 2.5
│ ├╴󰗠 1
│ ├╴󰗠 2
│ ├╴󰄰 3
│ ╰╴󰄰 4
│   ├╴󰄰 5
│   ╰╴󰄰 6
├╴󰌖 2.6
╰╴󰌖 2.7
```

## numbers = false

```lua
require("toc").setup {
  preset = "compact",
  numbers = false,
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
│ │ ╰╴ code 1 [ sh]
│ ╰╴󰼑
│   ├╴ code 2 [ sh]
│   ╰╴󰋽 note 1
├╴󰌖
│ ├╴ table 1
│ ╰╴ warning 1
├╴󰌖
│ ├╴󰼑
│ ╰╴󰼑
│   ├╴󰎲
│   ╰╴󰎲
│     ╰╴ tip 1
├╴󰌖
│ ├╴󰗠 task 1
│ ├╴󰗠 task 2
│ ├╴󰄰 task 3
│ ╰╴󰄰 task 4
│   ├╴󰄰 task 5
│   ╰╴󰄰 task 6
├╴󰌖
╰╴󰌖
```

## labels = false, numbers = false

```lua
require("toc").setup {
  preset = "compact",
  labels = false,
  numbers = false,
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
│ │ ╰╴ 1 [ sh]
│ ╰╴󰼑
│   ├╴ 2 [ sh]
│   ╰╴󰋽 1
├╴󰌖
│ ├╴ 1
│ ╰╴ 1
├╴󰌖
│ ├╴󰼑
│ ╰╴󰼑
│   ├╴󰎲
│   ╰╴󰎲
│     ╰╴ 1
├╴󰌖
│ ├╴󰗠 1
│ ├╴󰗠 2
│ ├╴󰄰 3
│ ╰╴󰄰 4
│   ├╴󰄰 5
│   ╰╴󰄰 6
├╴󰌖
╰╴󰌖
```
