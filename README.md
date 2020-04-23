# zig-md2020

CommonMark compliant Markdown parsing for Zig!

[md2020](https://www.youtube.com/watch?v=dN61WU57zBw) is a library and command line tool for
converting markdown to html or showing rendered markdown in a webview.

## Usage

TBD

## Status

0/649 tests of the CommonMark 0.29 test suite pass!

### Milestone #1

Parse and display a basic document.

```
# Hello World

**Bold** text.

## Hello again

*Itaclics* text.

```
A code block.
```

## A list

1. One

   List item text.

1. Two

1. Three

```

- [ ] Tokenize
- [ ] Parse
- [ ] Render to HTML
- [ ] Display markdown document in [webview](https://github.com/zserge/webview).
