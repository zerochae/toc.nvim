# Nebula CLI

A GitHub-flavoured README that leans on inline HTML — the kind toc.nvim now
reads through the same scanner as standalone `.html` files. Open it and run
`:Toc` to see markdown headings, HTML disclosures, tables, and inline anchors
in one outline.

<p align="center">
  <img alt="Nebula logo" src="assets/logo.svg" />
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
