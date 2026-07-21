# Changelog

## [1.1.0](https://github.com/zerochae/toc.nvim/compare/v1.0.1...v1.1.0) (2026-07-21)


### Features

* add max_level option to hide deeply nested entries ([#12](https://github.com/zerochae/toc.nvim/issues/12)) ([1c03d1f](https://github.com/zerochae/toc.nvim/commit/1c03d1f6082c7a24792b4a96f91fb0c90f8914ca))
* skip YAML/TOML front matter in the markdown parser ([#11](https://github.com/zerochae/toc.nvim/issues/11)) ([6020114](https://github.com/zerochae/toc.nvim/commit/6020114a0483aef47c9d0eb80c5bfabca1f821ab))


### Bug Fixes

* parse code, callouts and list items in the HTML regex fallback ([#13](https://github.com/zerochae/toc.nvim/issues/13)) ([2157a09](https://github.com/zerochae/toc.nvim/commit/2157a09ffdccfa05c4e0c747ba522d70b83e8040))

## [1.0.1](https://github.com/zerochae/toc.nvim/compare/v1.0.0...v1.0.1) (2026-07-21)


### Bug Fixes

* parse HTML tables in the regex fallback without treesitter ([#8](https://github.com/zerochae/toc.nvim/issues/8)) ([a4dccd8](https://github.com/zerochae/toc.nvim/commit/a4dccd8cc26ca0e567733f8a5427713c65251bbf))

## 1.0.0 (2026-07-21)


### Features

* add a treesitter HTML parser (with regex fallback) ([3efe371](https://github.com/zerochae/toc.nvim/commit/3efe37152e1b9fcabbd78784e6f188c82dd77880))
* auto-close the TOC on non-markdown buffers ([9445fdb](https://github.com/zerochae/toc.nvim/commit/9445fdb2c6735c6a7176b9b171115148a1569c1a))
* auto-open the TOC for HTML files ([185c5f1](https://github.com/zerochae/toc.nvim/commit/185c5f189c06e6784b0db6f00890e7e791126ca0))
* detect &gt;lang code blocks in help and auto-open help files ([04aab05](https://github.com/zerochae/toc.nvim/commit/04aab05602f5e0e8f5fdbf1c5e12070fb14aab50))
* dispatch the parser by filetype and support Vim help files ([d683ffb](https://github.com/zerochae/toc.nvim/commit/d683ffb9889b458d32833e3a3196a0738b4802a1))
* index ~ subheadings, tags, code and callouts in Vim help files ([abd8da0](https://github.com/zerochae/toc.nvim/commit/abd8da06ff69f7b282acc7b8c3258fbb75944460))
* index HTML details/summary, tables and definition lists ([960d4e9](https://github.com/zerochae/toc.nvim/commit/960d4e90d265a36be89e2db9dbd46429a1d4ecad))
* initial toc.nvim implementation ([b316278](https://github.com/zerochae/toc.nvim/commit/b3162788ee5a1a84e2988d528f09ea1efe2c970e))
* start cursor on the first entry and restrict the TOC to vertical moves ([c9794ff](https://github.com/zerochae/toc.nvim/commit/c9794ffae27db84aee3ce7d66fa42517dcc817f8))
* unify HTML extraction via a shared scanner and expand the parser ([61052a0](https://github.com/zerochae/toc.nvim/commit/61052a015894d95b288be312b13368d8e9ed2fe2))
* validate config and harden table parsing and health checks ([b82dce7](https://github.com/zerochae/toc.nvim/commit/b82dce730f9c9bebf271f55be1426e3710dd7fc4))


### Bug Fixes

* clean markdown syntax from HTML titles and stop table-cell leaks ([bc915d6](https://github.com/zerochae/toc.nvim/commit/bc915d6ca8ede3c3853bae2e1af918bf0b4cdb40))
* nest inline links under bullets and lift the beacon above markview ([ff1cc85](https://github.com/zerochae/toc.nvim/commit/ff1cc85e80fb6fca38b39fa6d63bac39f0809d67))
* type layout.build marks as TocMark[] so the fg field resolves ([a25cc83](https://github.com/zerochae/toc.nvim/commit/a25cc83e3f5d38b9fdbc5affbc5f799a02ddbfb9))
