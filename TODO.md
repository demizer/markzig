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


# Things To Do

## Fri Apr 10 16:25 2020: Tokenize a simple document using tests

I must get the most basic document fully parsed to not fall into a trap of not seeing gratifying
results and giving up like I did with the go-rst parser.

* Parsing leaf blocks
  * atx_headings
  * fenced code blocks
* Parse inline blocks (can be parallel)
