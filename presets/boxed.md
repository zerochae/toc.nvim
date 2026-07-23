# Preset: boxed

Roomy box-drawing tree; keeps Nerd Font glyphs and markview colours.

Rendered for the *Widget Service* section of [demo.md](../tests/fixtures/demo.md).
Variations show how `labels` / `numbers` change the output on top of this
preset (identical variations are omitted).

## Base

```lua
require("toc").setup {
  preset = "boxed",
}
```

```
󰌕 heading 1.1 Widget Service
├─ 󰌖 heading 2.1 Overview
│  ├─ 󰼑 heading 3.1 Goals
│  └─ 󰼑 heading 3.2 Non-Goals
├─ 󰌖 heading 2.2 Getting Started
│  ├─ 󰼑 heading 3.3 Requirements
│  ├─ 󰼑 heading 3.4 Install
│  │  └─  code 1 [ sh]
│  └─ 󰼑 heading 3.5 First Run
│     ├─  code 2 [ sh]
│     └─ 󰋽 note 1 The server bi…
├─ 󰌖 heading 2.3 Configuration
│  ├─  table 1 Key
│  └─  warning 1 Disabling the…
├─ 󰌖 heading 2.4 Architecture
│  ├─ 󰼑 heading 3.6 Request Flow
│  └─ 󰼑 heading 3.7 Modules
│     ├─ 󰎲 heading 4.1 Parser
│     └─ 󰎲 heading 4.2 Renderer
│        └─  tip 1 The rendere…
├─ 󰌖 heading 2.5 Roadmap
│  ├─ 󰗠 task 1 HTTP endpoint
│  ├─ 󰗠 task 2 Render cache
│  ├─ 󰄰 task 3 Streaming respon…
│  └─ 󰄰 task 4 Plugin API
│     ├─ 󰄰 task 5 Discovery
│     └─ 󰄰 task 6 Sandboxing
├─ 󰌖 heading 2.6 References
└─ 󰌖 heading 2.7 License
```

## labels = false

```lua
require("toc").setup {
  preset = "boxed",
  labels = false,
}
```

```
󰌕 1.1 Widget Service
├─ 󰌖 2.1 Overview
│  ├─ 󰼑 3.1 Goals
│  └─ 󰼑 3.2 Non-Goals
├─ 󰌖 2.2 Getting Started
│  ├─ 󰼑 3.3 Requirements
│  ├─ 󰼑 3.4 Install
│  │  └─  1 [ sh]
│  └─ 󰼑 3.5 First Run
│     ├─  2 [ sh]
│     └─ 󰋽 1 The server binds t…
├─ 󰌖 2.3 Configuration
│  ├─  1 Key
│  └─  1 Disabling the cache r…
├─ 󰌖 2.4 Architecture
│  ├─ 󰼑 3.6 Request Flow
│  └─ 󰼑 3.7 Modules
│     ├─ 󰎲 4.1 Parser
│     └─ 󰎲 4.2 Renderer
│        └─  1 The renderer is…
├─ 󰌖 2.5 Roadmap
│  ├─ 󰗠 1 HTTP endpoint
│  ├─ 󰗠 2 Render cache
│  ├─ 󰄰 3 Streaming responses
│  └─ 󰄰 4 Plugin API
│     ├─ 󰄰 5 Discovery
│     └─ 󰄰 6 Sandboxing
├─ 󰌖 2.6 References
└─ 󰌖 2.7 License
```

## numbers = false

```lua
require("toc").setup {
  preset = "boxed",
  numbers = false,
}
```

```
󰌕 Widget Service
├─ 󰌖 Overview
│  ├─ 󰼑 Goals
│  └─ 󰼑 Non-Goals
├─ 󰌖 Getting Started
│  ├─ 󰼑 Requirements
│  ├─ 󰼑 Install
│  │  └─  code 1 [ sh]
│  └─ 󰼑 First Run
│     ├─  code 2 [ sh]
│     └─ 󰋽 note 1 The server bi…
├─ 󰌖 Configuration
│  ├─  table 1 Key
│  └─  warning 1 Disabling the…
├─ 󰌖 Architecture
│  ├─ 󰼑 Request Flow
│  └─ 󰼑 Modules
│     ├─ 󰎲 Parser
│     └─ 󰎲 Renderer
│        └─  tip 1 The rendere…
├─ 󰌖 Roadmap
│  ├─ 󰗠 task 1 HTTP endpoint
│  ├─ 󰗠 task 2 Render cache
│  ├─ 󰄰 task 3 Streaming respon…
│  └─ 󰄰 task 4 Plugin API
│     ├─ 󰄰 task 5 Discovery
│     └─ 󰄰 task 6 Sandboxing
├─ 󰌖 References
└─ 󰌖 License
```

## labels = false, numbers = false

```lua
require("toc").setup {
  preset = "boxed",
  labels = false,
  numbers = false,
}
```

```
󰌕 Widget Service
├─ 󰌖 Overview
│  ├─ 󰼑 Goals
│  └─ 󰼑 Non-Goals
├─ 󰌖 Getting Started
│  ├─ 󰼑 Requirements
│  ├─ 󰼑 Install
│  │  └─  1 [ sh]
│  └─ 󰼑 First Run
│     ├─  2 [ sh]
│     └─ 󰋽 1 The server binds t…
├─ 󰌖 Configuration
│  ├─  1 Key
│  └─  1 Disabling the cache r…
├─ 󰌖 Architecture
│  ├─ 󰼑 Request Flow
│  └─ 󰼑 Modules
│     ├─ 󰎲 Parser
│     └─ 󰎲 Renderer
│        └─  1 The renderer is…
├─ 󰌖 Roadmap
│  ├─ 󰗠 1 HTTP endpoint
│  ├─ 󰗠 2 Render cache
│  ├─ 󰄰 3 Streaming responses
│  └─ 󰄰 4 Plugin API
│     ├─ 󰄰 5 Discovery
│     └─ 󰄰 6 Sandboxing
├─ 󰌖 References
└─ 󰌖 License
```
