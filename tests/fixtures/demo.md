# toc.nvim Demo Document

An exhaustive fixture for eyeballing the TOC panel. Open this file and run
`:Toc` (or let it auto-open) to see every element kind rendered. It bundles
three documents: an element showcase, a natural project guide (the source the
[preset gallery](../../presets/) renders), and an HTML-heavy README.

## Headings

### ATX Level 3

#### ATX Level 4

##### ATX Level 5

###### ATX Level 6

Setext Heading One
==================

Setext Heading Two
------------------

<h2 id="html-section">Raw HTML Heading (h2)</h2>

<h3>Raw HTML Heading (h3)</h3>

---

# Level Jump Demo

### Jumped Straight To H3 (skipped H2)

## Tasks

- [ ] Unchecked task
- [x] Checked task
- [ ] Parent task
  - [ ] Nested subtask
  - [x] Nested done subtask
- [X] Uppercase checked
- [/] test
- [u] test
- [!] test

## Code Blocks

```lua
local function hello()
  print("world")
end
```

```python
def hello():
    print("world")
```

```
plain fenced block, no language
```

### Nested Fences

````markdown
```lua
-- this inner block must NOT close the outer fence
print("still inside")
```
````

## Callouts

> [!NOTE] This is a note callout
> with extra body text.

> [!WARNING] Be careful here

> [!TIP]
> A tip with the title on the next line.

## Tables

| Column A | Column B | Column C |
| -------- | -------- | -------- |
| 1        | 2        | 3        |
| 4        | 5        | 6        |

## Media & Links

![architecture diagram](./assets/diagram.png)

![](./assets/no-alt.png)

Here is an [inline link](https://example.com) inside a paragraph, plus a
[second link](https://neovim.io) right after it.
[thrid link](https://neovim.io)
## Bullets

- Top-level bullet
- Another bullet
  - Nested bullet
  - Nested bullet two
- Back to top level

## Edge Cases

###    Heading With Extra Leading Spaces

## This Is An Intentionally Very Long Heading Title Meant To Overflow The Fixed Width Panel So Truncation Kicks In

## Trailing Hashes Heading ##

#NotAHeading (no space after hash, should be ignored)

## Final Section

The end.

---

# Widget Service

A small service that renders widgets. This document reads like a real project
guide — the [preset gallery](../../presets/) renders this section.

## Overview

Widget Service turns definitions into rendered widgets over HTTP. It aims to be
small, predictable, and easy to embed.

### Goals

- Deterministic output for a given input
- Sub-10ms render latency
- Zero required configuration

### Non-Goals

- Persistence or a database
- Multi-tenant auth

## Getting Started

### Requirements

- Rust 1.75+
- `make`

### Install

```sh
git clone https://example.com/widget-service
cd widget-service
make build
```

### First Run

```sh
./target/release/widget-service --port 8080
```

> [!NOTE] The server binds to localhost only unless `--host` is given.

## Configuration

Settings are read from `config.toml`, then overridden by environment variables.

| Key        | Default | Description                 |
| ---------- | ------- | --------------------------- |
| `port`     | `8080`  | Listen port                 |
| `host`     | `127.0.0.1` | Bind address            |
| `cache`    | `true`  | Enable the render cache     |

> [!WARNING] Disabling the cache roughly triples render latency.

## Architecture

### Request Flow

1. Parse the incoming definition
2. Validate against the schema
3. Render and cache

### Modules

#### Parser

Turns raw text into an AST.

#### Renderer

Walks the AST and emits pixels.

> [!TIP] The renderer is pure — same AST always yields the same bytes.

## Roadmap

- [x] HTTP endpoint
- [x] Render cache
- [ ] Streaming responses
- [ ] Plugin API
  - [ ] Discovery
  - [ ] Sandboxing

## References

See the [design doc](https://example.com/design) and the
[API reference](https://example.com/api) for details.

## License

MIT.

---

# Nebula CLI

A GitHub-flavoured README that leans on inline HTML — the kind toc.nvim reads
through the same scanner as standalone `.html` files. HTML disclosures, tables,
and inline anchors all show up in one outline.

<p align="center">
  <img alt="Nebula logo" src="../../assets/logo.svg" />
</p>

## Overview

Nebula packages your project into a single binary. See the
<a href="https://example.com/docs">full documentation</a> for the long form.

<details>
  <summary>Why another packager?</summary>

  Existing tools optimise for servers; Nebula optimises for CLIs.
</details>

<details>
  <summary>Supported platforms</summary>

  Linux, macOS, and Windows on both x86_64 and arm64.
</details>

## Installation

### From a release

- Download the <a href="https://example.com/releases">latest release</a>
- Extract it onto your `PATH`
- Run `nebula --version` to confirm

### From source

```sh
git clone https://example.com/nebula
cd nebula && make install
```

## Comparison

<table>
  <caption>Nebula vs. alternatives</caption>
  <thead>
    <tr>
      <th>Tool</th>
      <th>Cold start</th>
      <th>Binary size</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Nebula</td>
      <td>8ms</td>
      <td>4MB</td>
    </tr>
    <tr>
      <td>Others</td>
      <td>40ms</td>
      <td>22MB</td>
    </tr>
  </tbody>
</table>

## Glossary

<dl>
  <dt>Bundle</dt>
  <dd>A self-contained, runnable artifact.</dd>
  <dt>Manifest</dt>
  <dd>The declarative build description.</dd>
</dl>

## Links

- [Issue tracker](https://example.com/issues)
- [Changelog](https://example.com/changelog)
- Chat on <a href="https://example.com/chat">the community server</a>
