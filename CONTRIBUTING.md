# Contributing to toc.nvim

Thanks for your interest. This guide covers the local workflow and how to add a
new file format.

## Development

Requirements: Neovim 0.10+, [stylua](https://github.com/JohnnyMorganz/StyLua),
and [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) for the test suite.

```sh
make test          # run the behaviour suite (plenary busted)
make format        # apply stylua formatting
make format-check  # verify formatting without writing
make check         # lint + test (what CI runs)
```

`make test` looks for plenary.nvim in your plugin manager's install path
(lazy.nvim / packer / a `vendor` pack) or in `.tests/plenary.nvim`. CI runs the
same checks on every push and pull request across Neovim `stable` and
`nightly`, so `make check` locally should mirror the pipeline.

## Adding a parser for a new format

Parsers live under `lua/toc/parsers/` and share a small contract:

1. Subclass the base parser (`lua/toc/parsers/base.lua`). Set your metatable
   with `__index = Parser`, add a `new(bufnr)` that calls `Parser.new`, and
   implement `parse()` returning `self.entries`.
2. Emit entries with `self:add { lnum, level, kind, text, ... }`. Use
   `self:enabled(kind)` to respect the user's `elements` config and
   `self:child_level()` to nest non-heading entries under the current heading.
3. Register the filetype in `lua/toc/parser.lua`'s `by_filetype` table. The
   dispatcher sorts entries by line, level, and insertion order for you.

See `lua/toc/parsers/help.lua` for a compact reference implementation.

## Tests

Behaviour tests are in `tests/toc_spec.lua` and run through a tiny inline
assertion harness (no external dependencies). Add cases alongside the existing
ones and keep the suite green before opening a pull request.
