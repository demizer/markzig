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

// "markdown": "# foo\n## foo\n### foo\n#### foo\n##### foo\n###### foo\n",
// "html": "<h1>foo</h1>\n<h2>foo</h2>\n<h3>foo</h3>\n<h4>foo</h4>\n<h5>foo</h5>\n<h6>foo</h6>\n",
test "Test Example 032" {
    const testNumber: u8 = 32;
    const parserInput = try testUtil.getTest(allocator, testNumber, testUtil.TestKey.markdown);
    testUtil.dumpTest(parserInput);
    var p = Parser.init(allocator);
    defer p.deinit();
    _ = try p.parse(parserInput);
    log.Debug("Testing lexer");
    const expectLexerJson = @embedFile("expect/03-section-atx-headings/testl_032.json");
    if (try testUtil.compareJsonExpect(allocator, expectLexerJson, p.lex.tokens.items)) |ajson| {
        // log.Errorf("LEXER TEST FAILED! lexer tokens (in json):\n{}\n", .{ajson});
        std.os.exit(1);
    }
    log.Debug("Testing parser");
    const expectParserJson = @embedFile("expect/03-section-atx-headings/testp_032.json");
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
