# toc.nvim Demo Document

An exhaustive fixture for eyeballing the TOC panel. Open this file and run
`:Toc` (or let it auto-open) to see every element kind rendered.

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
