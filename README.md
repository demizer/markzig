# Markzig

![GitHub Workflow Status](https://img.shields.io/github/workflow/status/demizer/markzig/build)
![Spec Status: 5/649](https://img.shields.io/badge/tests-5%2F649-brightgreen.svg)

CommonMark compliant Markdown parsing for Zig!

Markzig is a library and command line tool for converting markdown to html or showing rendered markdown in a webview.

The webview is the only non-zig feature. It is written in C++ and requires GTK3.

NOTE: the webview does not currently compile due to https://github.com/ziglang/zig/issues/7094

## Usage

Not yet applicable.

## Status

5/649 tests of the CommonMark 0.29 test suite pass!

### Milestone #1

Parse and display a basic document [test.md](https://github.com/demizer/markzig/blob/master/test/test.md).

- [ ] Tokenize
- [ ] Parse
- [ ] Render to HTML
- [X] Display markdown document in [webview](https://github.com/zserge/webview).

### Milestone #2

- [ ] 50% tests pass
