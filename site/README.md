# site/ — landing page source

The GitHub Pages site in [`../docs`](../docs) is **generated**. Do not edit
`docs/` by hand — edit the source here and rebuild.

## Build

```sh
python3 site/build.py
```

Regenerates `docs/index.html`, `docs/styles.css`, `docs/main.js`, and copies
`assets/logo.svg`. Requires Python 3 with `fonttools` + `brotli`:

```sh
python3 -m pip install --user fonttools brotli
```

## Files

| Path | What |
|------|------|
| `template.html` | The page: `<style>`, markup with `{{SLOTS}}`, `<script>`. |
| `build.py` | Fills slots (hero preset-switcher, preset panels), subsets the font, writes `docs/`. |
| `fonts/jbmono-*.woff2` | JetBrainsMono Nerd Font, **subset** to the glyphs the page uses (OFL, redistributable). |
| `preview.single.html` | Self-contained single file (fonts inlined) for the claude.ai artifact preview. Not served by Pages. |

## Fonts

`build.py` subsets JetBrainsMono Nerd Font down to only the characters shown
(~5 KB per weight). If the source TTFs are installed at
`~/Library/Fonts/JetBrainsMonoNerdFont-{Regular,Bold}.ttf`, they are re-subset
and `fonts/*.woff2` are refreshed. Otherwise the committed `fonts/*.woff2` are
reused, so the build works without the font installed — unless you add new
glyphs to the page, in which case rebuild on a machine that has the font.

## The hero preset switcher

`template.html` has a `{{HERO_SPLIT}}` slot. `build.py` renders an example
markdown document (`OUTLINE`) as a TOC panel in each preset (`default`,
`compact`, `boxed`, `writing`, `plain`) and the tabs swap between them. Edit
`OUTLINE` / `SRC` / `CFG` in `build.py` to change the demo.
