# Markzig

![GitHub Workflow Status](https://img.shields.io/github/workflow/status/demizer/markzig/build)
![Test Status: 5/649](https://img.shields.io/badge/Specs-5%2F649-brightgreen.svg)

CommonMark compliant Markdown parsing for Zig!

Markzig is a library and command line tool for converting markdown to html or showing rendered markdown in a webview.

The webview is the only non-zig feature. It is written in C++ and requires GTK3.

NOTE: the webview does not currently compile due to https://github.com/ziglang/zig/issues/7094

## Usage

```
zig build && ./zig-cache/bin/mdv --debug view test/docs/test_headings.md
```
