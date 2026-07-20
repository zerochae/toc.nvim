# Preset: writing

Prose outline: headings only, text-first, hierarchical numbers, no tree lines.

Rendered for [demo2.md](./demo2.md). Variations show how `labels` / `numbers`
change the output on top of this preset (identical variations are omitted).

## Base

```lua
require("toc").setup {
  preset = "writing",
}
```

```
heading 1 Widget Service
  heading 1.1 Overview
    heading 1.1.1 Goals
    heading 1.1.2 Non-Goals
  heading 1.2 Getting Started
    heading 1.2.1 Requirements
    heading 1.2.2 Install
    heading 1.2.3 First Run
  heading 1.3 Configuration
  heading 1.4 Architecture
    heading 1.4.1 Request Flow
    heading 1.4.2 Modules
      heading 1.4.2.1 Parser
      heading 1.4.2.2 Renderer
  heading 1.5 Roadmap
  heading 1.6 References
  heading 1.7 License
```

## labels = false

```lua
require("toc").setup {
  preset = "writing",
  labels = false,
}
```

```
1 Widget Service
  1.1 Overview
    1.1.1 Goals
    1.1.2 Non-Goals
  1.2 Getting Started
    1.2.1 Requirements
    1.2.2 Install
    1.2.3 First Run
  1.3 Configuration
  1.4 Architecture
    1.4.1 Request Flow
    1.4.2 Modules
      1.4.2.1 Parser
      1.4.2.2 Renderer
  1.5 Roadmap
  1.6 References
  1.7 License
```

## numbers = false

```lua
require("toc").setup {
  preset = "writing",
  numbers = false,
}
```

```
Widget Service
  Overview
    Goals
    Non-Goals
  Getting Started
    Requirements
    Install
    First Run
  Configuration
  Architecture
    Request Flow
    Modules
      Parser
      Renderer
  Roadmap
  References
  License
```

## labels = false, numbers = false

```lua
require("toc").setup {
  preset = "writing",
  labels = false,
  numbers = false,
}
```

```
Widget Service
  Overview
    Goals
    Non-Goals
  Getting Started
    Requirements
    Install
    First Run
  Configuration
  Architecture
    Request Flow
    Modules
      Parser
      Renderer
  Roadmap
  References
  License
```
