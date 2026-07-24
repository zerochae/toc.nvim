#!/usr/bin/env python3
"""Build the toc.nvim landing page into ../docs (GitHub Pages) + a single-file
preview. Run:  python3 site/build.py

Fonts: JetBrainsMono Nerd Font is subset to only the glyphs the page uses.
If the source TTFs are installed (~/Library/Fonts), they are re-subset and the
committed woff2 in site/fonts/ are refreshed; otherwise the committed woff2 are
reused as-is (so the build works without the font installed)."""
import base64, re, os, shutil, subprocess, string, sys, html

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
DOCS = os.path.join(REPO, "docs")
PRESETS = os.path.join(REPO, "presets")
FONTDIR = os.path.join(HERE, "fonts")
TEMPLATE = os.path.join(HERE, "template.html")
REG_WOFF2 = os.path.join(FONTDIR, "jbmono-reg.woff2")
BOLD_WOFF2 = os.path.join(FONTDIR, "jbmono-bold.woff2")
FONT_REG = os.path.expanduser("~/Library/Fonts/JetBrainsMonoNerdFont-Regular.ttf")
FONT_BOLD = os.path.expanduser("~/Library/Fonts/JetBrainsMonoNerdFont-Bold.ttf")

src = open(TEMPLATE, encoding="utf-8").read()

def esc(s):
    return html.escape(s, quote=False)

# ---- Nerd Font glyphs ----
G = {
    "title": "\U000f0836",
    "h1": "\U000f0315", "h2": "\U000f0316", "h3": "\U000f0f11", "h4": "\U000f03b2",
    "done": "\U000f05e0", "todo": "\U000f0130", "note": "\U000f02fd",
}
_bx = open(os.path.join(PRESETS, "boxed.md"), encoding="utf-8").read()
def _gbefore(word, default=""):
    mm = re.search(r"(\S)\s+%s \d" % word, _bx)
    return mm.group(1) if mm else default
for _w in ("code", "table", "warning", "tip"):
    G[_w] = _gbefore(_w)

# ---- markview-style colouriser (preset panels) ----
TREE = set("│├╰╴─└┐┘┌ ")
GLYPH_CLASS = {
    G["h1"]: "cl1", G["h2"]: "cl2", G["h3"]: "cl3", G["h4"]: "cl4",
    G["done"]: "cok", G["todo"]: "cno", G["note"]: "cnote",
    G["code"]: "ccode", G["table"]: "ctable", G["warning"]: "cwarn", G["tip"]: "ctip",
}
KW_CLASS = {"table": "ctable", "note": "cnote", "warning": "cwarn", "tip": "ctip", "code": "ccode"}

def _numspan(s):
    return re.sub(r"(\d+(?:\.\d+)*)", r'<span class="nm">\1</span>', esc(s))

def colorize(line):
    j = 0
    while j < len(line) and line[j] in TREE:
        j += 1
    tree, rest = line[:j], line[j:]
    out = f'<span class="tr">{esc(tree)}</span>' if tree else ""
    if not rest:
        return out
    cls = None
    glyph = ""
    if rest[0] in GLYPH_CLASS:
        glyph, cls, rest = rest[0], GLYPH_CLASS[rest[0]], rest[1:]
    else:
        mh = re.match(r"#{1,6}", rest)
        mt = re.match(r"\[[ x]\]", rest)
        if mh and rest[mh.end():mh.end() + 1] in (" ", ""):
            kw = rest[mh.end():].lstrip().split(" ", 1)[0]
            glyph, rest = rest[:mh.end()], rest[mh.end():]
            cls = KW_CLASS.get(kw, "cl%d" % min(mh.end(), 4))
        elif mt:
            glyph, rest = mt.group(0), rest[mt.end():]
            cls = "cok" if "x" in glyph else "cno"
        elif rest[0] == "!":
            kw = rest[1:].lstrip().split(" ", 1)[0]
            glyph, rest = "!", rest[1:]
            cls = KW_CLASS.get(kw, "cwarn")
    is_heading = cls in ("cl1", "cl2", "cl3", "cl4")
    glyph_html = f'<span class="{cls}">{esc(glyph)}</span>' if cls else esc(glyph)
    rest_html = _numspan(rest)
    if is_heading:
        rest_html = f'<span class="{cls}">{rest_html}</span>'
    return out + glyph_html + rest_html

# ================= hero: interactive preset switcher =================
def srow(n, content, key=None):
    k = f' data-k="{key}"' if key else ""
    return f'<span class="row"{k}><span class="ln">{n}</span>{content}</span>'

SRC = [
    srow(1, '<span class="cl1"># Widget Service</span>', "1"),
    srow(2, ""),
    srow(3, '<span class="cl2">## Overview</span>', "3"),
    srow(4, '<span class="cl3">### Goals</span>', "4"),
    srow(5, '<span class="cl3">### Non-Goals</span>', "5"),
    srow(6, ""),
    srow(7, '<span class="cl2">## Getting Started</span>', "7"),
    srow(8, '<span class="cl3">### Install</span>', "8"),
    srow(9, ""),
    srow(10, '<span class="cl2">## Configuration</span>', "10"),
    srow(11, '<span class="cmark">- </span><span class="cok">[x]</span> HTTP endpoint', "11"),
    srow(12, '<span class="cmark">- </span><span class="cno">[ ]</span> Streaming', "12"),
    srow(13, '<span class="cmt">&gt; </span><span class="cnote">[!NOTE]</span> Binds to localhost.', "13"),
]

def N(kind, text, key, level=0, done=False, ch=None):
    return {"kind": kind, "text": text, "key": key, "level": level, "done": done, "ch": ch or []}

OUTLINE = N("heading", "Widget Service", "1", 1, ch=[
    N("heading", "Overview", "3", 2, ch=[
        N("heading", "Goals", "4", 3),
        N("heading", "Non-Goals", "5", 3),
    ]),
    N("heading", "Getting Started", "7", 2, ch=[
        N("heading", "Install", "8", 3),
    ]),
    N("heading", "Configuration", "10", 2, ch=[
        N("task", "HTTP endpoint", "11", done=True),
        N("task", "Streaming", "12", done=False),
        N("note", "Binds to lo…", "13"),
    ]),
])

def number_level(root):
    num, lc, tc = {}, {}, {}
    def walk(n):
        if n["kind"] == "heading":
            lc[n["level"]] = lc.get(n["level"], 0) + 1
            num[n["key"]] = f'{n["level"]}.{lc[n["level"]]}'
        else:
            tc[n["kind"]] = tc.get(n["kind"], 0) + 1
            num[n["key"]] = str(tc[n["kind"]])
        for c in n["ch"]:
            walk(c)
    walk(root)
    return num

def number_nested(root):
    num = {}
    def walk(n, path):
        num[n["key"]] = ".".join(path)
        hs = [c for c in n["ch"] if c["kind"] == "heading"]
        for i, c in enumerate(hs, 1):
            walk(c, path + [str(i)])
    walk(root, ["1"])
    return num

NUM = {"level": number_level(OUTLINE), "nested": number_nested(OUTLINE)}

def glyph_of(node, ascii_):
    k = node["kind"]
    if k == "heading":
        lv = min(node["level"], 4)
        return (("#" * node["level"]) if ascii_ else G[f"h{lv}"]), f"cl{lv}"
    if k == "task":
        if ascii_:
            return ("[x]" if node["done"] else "[ ]"), ("cok" if node["done"] else "cno")
        return (G["done"] if node["done"] else G["todo"]), ("cok" if node["done"] else "cno")
    if k == "note":
        return (("!" if ascii_ else G["note"]), "cnote")
    return "", ""

THIN = {"branch": "├╴", "last": "╰╴", "vert": "│ ", "blank": "  "}
BOX = {"branch": "├─ ", "last": "└─ ", "vert": "│  ", "blank": "   "}
CFG = {
    "default": dict(mode="full", num="level", tree=THIN, ascii=False, elements=True, title=True, tglyph=True),
    "compact": dict(mode="glyph", num="level", tree=THIN, ascii=False, elements=True, title=False, tglyph=False),
    "boxed": dict(mode="full", num="level", tree=BOX, ascii=False, elements=True, title=True, tglyph=True),
    "writing": dict(mode="text", num="nested", tree=None, ascii=False, elements=False, title=True, tglyph=True),
    "plain": dict(mode="full", num="level", tree=BOX, ascii=True, elements=True, title=True, tglyph=False),
}

def entry(prefix, node, cfg):
    mode = cfg["mode"]
    g, gcls = glyph_of(node, cfg["ascii"])
    num = NUM[cfg["num"]].get(node["key"], "") if cfg["num"] else ""
    is_head = node["kind"] == "heading"
    seg = []
    if mode != "text" and g != "":
        seg.append(f'<span class="{gcls}">{esc(g)}</span>')
    if num and mode != "minimal":
        seg.append(f'<span class="nm">{num}</span>')
    if mode in ("full", "text"):
        t = esc(node["text"])
        seg.append(f'<span class="{gcls}">{t}</span>' if is_head else t)
    tr = f'<span class="tr">{esc(prefix)}</span>' if prefix else ""
    return f'<span class="e" data-k="{node["key"]}">{tr}{" ".join(seg)}</span>'

def render(cfg):
    lines = []
    def kids(n):
        return [c for c in n["ch"] if cfg["elements"] or c["kind"] == "heading"]
    if cfg["tree"] is None:
        def walk_flat(n):
            if n["kind"] != "heading":
                return
            lines.append(entry("  " * (n["level"] - 1), n, cfg))
            for c in kids(n):
                walk_flat(c)
        walk_flat(OUTLINE)
    else:
        T = cfg["tree"]
        def walk_tree(n, prefix, conn):
            lines.append(entry(prefix + conn, n, cfg))
            ext = "" if conn == "" else (T["blank"] if conn == T["last"] else T["vert"])
            ks = kids(n)
            for i, c in enumerate(ks):
                walk_tree(c, prefix + ext, T["last"] if i == len(ks) - 1 else T["branch"])
        walk_tree(OUTLINE, "", "")
    tt = ""
    if cfg["title"]:
        g = (G["title"] + " ") if cfg["tglyph"] else ""
        tt = f'<div class="tt">{g}Table of Contents</div>'
    return tt + "".join(lines)

TABS = ["default", "compact", "boxed", "writing", "plain"]
tabbar = "".join(
    f'<button class="tab{" on" if p == "default" else ""}" data-preset="{p}">{p}</button>' for p in TABS)
panels = "".join(
    f'<div class="toc" data-preset="{p}"{"" if p == "default" else " hidden"}>{render(CFG[p])}</div>' for p in TABS)

hero = (
    '<div class="editor" aria-label="toc.nvim as text: markdown source on the left, table-of-contents panel on the right">'
    '<div class="bar"><i class="dr"></i><i class="dy"></i><i class="dg"></i><span class="name">demo.md</span></div>'
    f'<div class="tabbar">{tabbar}</div>'
    '<div class="panes">'
    '<div class="src">' + "".join(SRC) + "</div>"
    f'<div class="tocwrap">{panels}</div>'
    "</div></div>"
)
src = src.replace("{{HERO_SPLIT}}", hero)

# ---- preset Base output blocks (colourised) ----
def base_block(name):
    md = open(os.path.join(PRESETS, f"{name}.md"), encoding="utf-8").read()
    sec = re.search(r"## Base\b(.*?)(?:\n## |\Z)", md, re.S).group(1)
    for info, body in re.findall(r"```(\w*)\n(.*?)\n```", sec, re.S):
        if info == "":
            return body.rstrip("\n")
    raise SystemExit(f"no plain block in {name}.md")

for p in ("compact", "boxed", "writing", "plain"):
    colored = "\n".join(colorize(l) for l in base_block(p).split("\n"))
    src = src.replace("{{PRESET_%s}}" % p.upper(), colored)

# ---- Formats chips with devicon (lang) glyphs ----
# (name, glyph, brand-ish colour, trailing text, optional?)
FORMATS = [
    ("Markdown", "", "#abb2bf", "", False),
    ("Vim help", "", "#98c379", "", False),
    ("Org", "", "#c678dd", "", False),
    ("reStructuredText", "", "#56b6c2", "", False),
    ("HTML", "", "#d19a66", " treesitter", True),
]
def fmt_chip(name, glyph, color, extra, opt):
    cls = ' class="opt"' if opt else ""
    return (f'<span{cls}><span class="fdev" style="color:{color}">{glyph}</span>'
            f'<b>{esc(name)}</b>{esc(extra)}</span>')
src = src.replace("{{FORMATS}}", "".join(fmt_chip(*f) for f in FORMATS))

# ---- fonts: subset from system TTF if present, else reuse committed woff2 ----
markup = re.search(r"</style>\s*(.*?)\s*<script>", src, re.S).group(1)
text = html.unescape(re.sub(r"<[^>]+>", "", markup))

def subset(ttf, out):
    chars = (set(text) | set(string.printable)) - {"\x0b", "\x0c"}
    charfile = os.path.join(HERE, "used_chars.txt")
    open(charfile, "w", encoding="utf-8").write("".join(sorted(chars)))
    subprocess.run([sys.executable, "-m", "fontTools.subset", ttf,
        f"--text-file={charfile}", "--flavor=woff2", f"--output-file={out}",
        "--layout-features=", "--no-hinting", "--desubroutinize", "--name-IDs="],
        check=True, capture_output=True)

if os.path.exists(FONT_REG) and os.path.exists(FONT_BOLD):
    subset(FONT_REG, REG_WOFF2)
    subset(FONT_BOLD, BOLD_WOFF2)
    font_note = "re-subset from system TTF"
else:
    assert os.path.exists(REG_WOFF2) and os.path.exists(BOLD_WOFF2), \
        "no system JetBrainsMono Nerd Font and no committed site/fonts/*.woff2"
    font_note = "reused committed woff2 (system font not found)"

# verify the woff2 covers every glyph the page renders
from fontTools.ttLib import TTFont
cmap = TTFont(REG_WOFF2).getBestCmap()
missing = sorted({c for c in text if ord(c) > 0x2000 and ord(c) not in cmap})
assert not missing, ("committed font is missing glyphs "
    + " ".join(f"U+{ord(c):X}" for c in missing)
    + " — rebuild on a machine with JetBrainsMono Nerd Font installed")

def datauri(path):
    b = open(path, "rb").read()
    return "data:font/woff2;base64," + base64.b64encode(b).decode(), len(b)

reg_uri, reg_sz = datauri(REG_WOFF2)
bold_uri, bold_sz = datauri(BOLD_WOFF2)
print(f"font: {font_note} | reg {reg_sz//1024}KB, bold {bold_sz//1024}KB")

# ---- single-file preview (for the claude.ai artifact; not served by Pages) ----
inline = src.replace("{{FONT_REGULAR}}", reg_uri).replace("{{FONT_BOLD}}", bold_uri)
assert "{{" not in inline, "leftover: " + re.search(r"\{\{[^}]+\}\}", inline).group(0)
open(os.path.join(HERE, "preview.single.html"), "w", encoding="utf-8").write(inline)

# ---- docs/ (split, image-free) ----
title = re.search(r"<title>(.*?)</title>", src, re.S).group(1)
css = re.search(r"<style>(.*?)</style>", src, re.S).group(1).strip()
js = re.search(r"<script>(.*?)</script>", src, re.S).group(1).strip()
css = css.replace("{{FONT_REGULAR}}", reg_uri).replace("{{FONT_BOLD}}", bold_uri)
assert "{{" not in css and "{{" not in markup

open(os.path.join(DOCS, "styles.css"), "w", encoding="utf-8").write(css + "\n")
open(os.path.join(DOCS, "main.js"), "w", encoding="utf-8").write(js + "\n")
shutil.copyfile(os.path.join(REPO, "assets", "logo.svg"), os.path.join(DOCS, "logo.svg"))
if os.path.isdir(os.path.join(DOCS, "img")):
    shutil.rmtree(os.path.join(DOCS, "img"))

docs = f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>{title}</title>
<meta name="description" content="A fancy table of contents for Markdown and more in a Neovim side split, with two-way cursor follow." />
<meta name="color-scheme" content="light dark" />
<link rel="icon" type="image/svg+xml" href="./logo.svg" />
<link rel="icon" type="image/png" sizes="32x32" href="./favicon-32.png" />
<link rel="apple-touch-icon" href="./apple-touch-icon.png" />
<link rel="stylesheet" href="./styles.css" />
<meta property="og:title" content="toc.nvim" />
<meta property="og:description" content="A fancy table of contents for Neovim, with two-way cursor follow." />
</head>
<body>
{markup}
<script src="./main.js" defer></script>
</body>
</html>
"""
open(os.path.join(DOCS, "index.html"), "w", encoding="utf-8").write(docs)
print(f"built docs/ | index.html {len(docs)//1024}KB | styles.css {len(css)//1024}KB | main.js {len(js)//1024}KB")
