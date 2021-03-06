# Links

* [golang markdown parser](https://gitlab.com/golang-commonmark/markdown/-/blob/master/markdown.go)
  The inspiration for this parser.
* [cmark](https://github.com/commonmark/cmark)
  The commonmark reference implementation in C.
* [md4t](https://github.com/mity/md4c)
  Another C markdown parser.
* [webview library](https://github.com/zserge/webview)
  This will be used to show the rendered markdown document with live updating.
* [Commonmark Spec 0.29](https://spec.commonmark.org/0.29/)
* [Commonmark Reference Implementations](https://github.com/commonmark/commonmark-spec/wiki/list-of-commonmark-implementations)
* [Zig Zasm](https://github.com/andrewrk/zasm/blob/master/src/main.zig)
* [Zig Docs](https://ziglang.org/documentation/master)
* [Zig Standard Library Docs](https://ziglang.org/documentation/master/std)
* [Zig Awesome Examples](https://github.com/nrdmn/awesome-zig)
* [Zig github search](https://github.com/search?q=json+getValue+language%3AZig+created%3A%3E2020-01-01&type=Code&ref=advsearch&l=&l=)
* [zig-window (xorg window)](https://github.com/andrewrk/zig-window)
* [zig-regex](https://github.com/tiehuis/zig-regex)
* [zhp (Http)](https://github.com/frmdstryr/zhp)
* [Let's build a simple interpreter](https://ruslanspivak.com/lsbasi-part1/)
* [astexplorer.net](https://astexplorer.net/)
  Examine an AST of a javascript markdown parser

# Things To Do

## Wed Nov 11 21:45 2020: INVESTIGATE: \n should be it's own token

   This might make it hard to detect newlines? I might be searching the string for \n to detect
   newlines.

   const input = "foo\nbar \t\nbaz";
   1605159814 [DEBUG]: lexer emit: { "ID": "Whitespace", "startOffset": 7, "endOffset": 9, "string": " \t\n", "lineNumber": 2, "column": 4 }

## Tue Nov 10 15:01 2020: add line number to log output

## Mon Nov 09 20:54 2020: combine lexer, parser, and html tests into one test function.

   Do each in order to reduce time to run tests.

## Mon Nov 09 18:13 2020: use html-diff in a container if the diff streamer fails

   https://github.com/bem/html-differ

## Mon Nov 09 21:57 2020: fix date/time logging in md/log.zig

## Mon Nov 09 21:26 2020: update outStream to writer in all files

## Mon Nov 09 21:56 2020: use testing.TmpDir instead of mktemp command

## Mon Nov 09 20:45 2020: fix linting errors is md/log.zig

### Sat Jun 06 13:47 2020: move test convert html 32 to parse test 32 test func

## Mon Jun 01 11:30 2020: Parse inline blocks

## Mon Jun 01 11:30 2020: Parse lists

## Mon Jun 01 15:54 2020: Add markzig to awesome-zig

## Mon Jun 01 11:31 2020: Announce on reddit

# DONE THINGS

## Sat Jun 06 13:39 2020: Remove the json / html comparitor
   :DONE: Mon Nov 09 20:38 2020

   It sucks. Just dump both the expect and got and that's it.

## Sun Oct 25 22:11 2020: rename project to markzig
   :DONE: Mon Nov 09 20:38 2020

## Mon Nov 09 11:36 2020: only run docker json-diff if the json actually differs.
   :DONE: Mon Nov 09 20:37 2020

   Get the old system from git history and restore it.

   Check the json using zig, if it fails, then use json-diff.

## Mon Nov 09 12:27 2020: printing of Token and Node should escape the string better:
   :DONE: Mon Nov 09 20:37 2020

   It's hard to see what is going on here:

   1604953496 [DEBUG]: expect: Token{ .ID = TokenId.Whitespace, .startOffset = 0, .endOffset = 0, .string =        , .lineNumber = 1, .column = 1 }
   1604953496 [DEBUG]: got: Token{ .ID = TokenId.Whitespace, .startOffset = 0, .endOffset = 0, .string =   , .lineNumber = 1, .column = 1 }

   The .string section should be escaped and enclosed with ''.

   Maybe there is a pretty print module for zig.
