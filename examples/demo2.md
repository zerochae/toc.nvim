# Widget Service

A small service that renders widgets. This document reads like a real project
guide — open it and run `:Toc` to see the outline on natural content.

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
