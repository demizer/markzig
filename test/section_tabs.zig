const std = @import("std");
const mem = std.mem;
const json = std.json;
const testing = std.testing;
const assert = std.debug.assert;

const testUtil = @import("util.zig");

const log = @import("../src/md/log.zig");
const Token = @import("../src/md/token.zig").Token;
const TokenId = @import("../src/md/token.zig").TokenId;
const Lexer = @import("../src/md/lexer.zig").Lexer;
const Parser = @import("../src/md/parse.zig").Parser;

var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
const allocator = &arena.allocator;

// "markdown": "\tfoo\tbaz\t\tbim\n",
// "html": "<pre><code>foo\tbaz\t\tbim\n</code></pre>\n",
test "Test Example 001" {
    const testNumber: u8 = 1;
    const parserInput = try testUtil.getTest(allocator, testNumber, testUtil.TestKey.markdown);
    testUtil.dumpTest(parserInput);
    var p = Parser.init(allocator);
    defer p.deinit();
    _ = try p.parse(parserInput);
    log.Debug("Testing lexer");
    const expectLexerJson = @embedFile("expect/01-section-tabs/testl_001.json");
    if (try testUtil.compareJsonExpect(allocator, expectLexerJson, p.lex.tokens.items)) |ajson| {
        // log.Errorf("LEXER TEST FAILED! lexer tokens (in json):\n{}\n", .{ajson});
        std.os.exit(1);
    }
    log.Debug("Testing parser");
    const expectParserJson = @embedFile("expect/01-section-tabs/testp_001.json");
    if (try testUtil.compareJsonExpect(allocator, expectParserJson, p.root.items)) |ajson| {
        // log.Errorf("PARSER TEST FAILED! parser tree (in json):\n{}\n", .{ajson});
        std.os.exit(1);
    }
    log.Debug("Testing html translator");
    const expectHtml = try testUtil.getTest(allocator, testNumber, testUtil.TestKey.html);
    defer allocator.free(expectHtml);
    if (try testUtil.compareHtmlExpect(allocator, expectHtml, &p.root)) |ahtml| {
        // log.Errorf("HTML TRANSLATE TEST FAILED! html:\n{}\n", .{ahtml});
        std.os.exit(1);
    }
}

// "markdown": "  \tfoo\tbaz\t\tbim\n",
// "html": "<pre><code>foo\tbaz\t\tbim\n</code></pre>\n",
test "Test Example 002" {
    const testNumber: u8 = 2;
    const parserInput = try testUtil.getTest(allocator, testNumber, testUtil.TestKey.markdown);
    testUtil.dumpTest(parserInput);
    var p = Parser.init(allocator);
    defer p.deinit();
    _ = try p.parse(parserInput);
    log.Debug("Testing lexer");
    const expectLexerJson = @embedFile("expect/01-section-tabs/testl_002.json");
    if (try testUtil.compareJsonExpect(allocator, expectLexerJson, p.lex.tokens.items)) |ajson| {
        // log.Errorf("LEXER TEST FAILED! lexer tokens (in json):\n{}\n", .{ajson});
        std.os.exit(1);
    }
    log.Debug("Testing parser");
    const expectParserJson = @embedFile("expect/01-section-tabs/testp_002.json");
    if (try testUtil.compareJsonExpect(allocator, expectParserJson, p.root.items)) |ajson| {
        // log.Errorf("PARSER TEST FAILED! parser tree (in json):\n{}\n", .{ajson});
        std.os.exit(1);
    }
    log.Debug("Testing html translator");
    const expectHtml = try testUtil.getTest(allocator, testNumber, testUtil.TestKey.html);
    defer allocator.free(expectHtml);
    if (try testUtil.compareHtmlExpect(allocator, expectHtml, &p.root)) |ahtml| {
        // log.Errorf("HTML TRANSLATE TEST FAILED! html:\n{}\n", .{ahtml});
        std.os.exit(1);
    }
}

// "markdown": "    a\ta\n    ὐ\ta\n",
// "html": "<pre><code>a\ta\nὐ\ta\n</code></pre>\n",
test "Test Example 003" {
    const testNumber: u8 = 3;
    const parserInput = try testUtil.getTest(allocator, testNumber, testUtil.TestKey.markdown);
    testUtil.dumpTest(parserInput);
    var p = Parser.init(allocator);
    defer p.deinit();
    _ = try p.parse(parserInput);
    log.Debug("Testing lexer");
    const expectLexerJson = @embedFile("expect/01-section-tabs/testl_003.json");
    if (try testUtil.compareJsonExpect(allocator, expectLexerJson, p.lex.tokens.items)) |ajson| {
        // log.Errorf("LEXER TEST FAILED! lexer tokens (in json):\n{}\n", .{ajson});
        std.os.exit(1);
    }
    log.Debug("Testing parser");
    const expectParserJson = @embedFile("expect/01-section-tabs/testp_003.json");
    if (try testUtil.compareJsonExpect(allocator, expectParserJson, p.root.items)) |ajson| {
        // log.Errorf("PARSER TEST FAILED! parser tree (in json):\n{}\n", .{ajson});
        std.os.exit(1);
    }
    log.Debug("Testing html translator");
    const expectHtml = try testUtil.getTest(allocator, testNumber, testUtil.TestKey.html);
    defer allocator.free(expectHtml);
    if (try testUtil.compareHtmlExpect(allocator, expectHtml, &p.root)) |ahtml| {
        // log.Errorf("HTML TRANSLATE TEST FAILED! html:\n{}\n", .{ahtml});
        std.os.exit(1);
    }
}

// "markdown": "  - foo\n\n\tbar\n",
// "html": "<ul>\n<li>\n<p>foo</p>\n<p>bar</p>\n</li>\n</ul>\n",
test "Test Example 004" {
    const testNumber: u8 = 4;
    const parserInput = try testUtil.getTest(allocator, testNumber, testUtil.TestKey.markdown);
    testUtil.dumpTest(parserInput);
    var p = Parser.init(allocator);
    defer p.deinit();
    _ = try p.parse(parserInput);
    log.Debug("Testing lexer");
    const expectLexerJson = @embedFile("expect/01-section-tabs/testl_004.json");
    if (try testUtil.compareJsonExpect(allocator, expectLexerJson, p.lex.tokens.items)) |ajson| {
        // log.Errorf("LEXER TEST FAILED! lexer tokens (in json):\n{}\n", .{ajson});
        std.os.exit(1);
    }
    log.Debug("Testing parser");
    const expectParserJson = @embedFile("expect/01-section-tabs/testp_004.json");
    if (try testUtil.compareJsonExpect(allocator, expectParserJson, p.root.items)) |ajson| {
        // log.Errorf("PARSER TEST FAILED! parser tree (in json):\n{}\n", .{ajson});
        std.os.exit(1);
    }
    log.Debug("Testing html translator");
    const expectHtml = try testUtil.getTest(allocator, testNumber, testUtil.TestKey.html);
    defer allocator.free(expectHtml);
    if (try testUtil.compareHtmlExpect(allocator, expectHtml, &p.root)) |ahtml| {
        // log.Errorf("HTML TRANSLATE TEST FAILED! html:\n\n'{}'\n", .{ahtml});
        std.os.exit(1);
    }
}

// "markdown": "- foo\n\n\t\tbar\n",
// "html": "<ul>\n<li>\n<p>foo</p>\n<pre><code>  bar\n</code></pre>\n</li>\n</ul>\n",
test "Test Example 005" {
    const testNumber: u8 = 5;
    const parserInput = try testUtil.getTest(allocator, testNumber, testUtil.TestKey.markdown);
    testUtil.dumpTest(parserInput);
    var p = Parser.init(allocator);
    defer p.deinit();
    _ = try p.parse(parserInput);
    log.Debug("Testing lexer");
    const expectLexerJson = @embedFile("expect/01-section-tabs/testl_005.json");
    if (try testUtil.compareJsonExpect(allocator, expectLexerJson, p.lex.tokens.items)) |ajson| {
        // log.Errorf("LEXER TEST FAILED! lexer tokens (in json):\n{}\n", .{ajson});
        std.os.exit(1);
    }
    log.Debug("Testing parser");
    const expectParserJson = @embedFile("expect/01-section-tabs/testp_005.json");
    if (try testUtil.compareJsonExpect(allocator, expectParserJson, p.root.items)) |ajson| {
        // log.Errorf("PARSER TEST FAILED! parser tree (in json):\n{}\n", .{ajson});
        std.os.exit(1);
    }
    log.Debug("Testing html translator");
    const expectHtml = try testUtil.getTest(allocator, testNumber, testUtil.TestKey.html);
    defer allocator.free(expectHtml);
    if (try testUtil.compareHtmlExpect(allocator, expectHtml, &p.root)) |ahtml| {
        // log.Errorf("HTML TRANSLATE TEST FAILED! html:\n\n'{}'\n", .{ahtml});
        std.os.exit(1);
    }
}
