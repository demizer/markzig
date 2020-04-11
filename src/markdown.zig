// Parse markdown for great good
//
// const std = @import("std");
// const mem = std.mem;
//
// const debug = @import("debug.zig");
//
// pub const Token = struct {
//     id: Id,
//     start: usize,
//     end: usize,
//
//     pub const Id = enum {
//         header,
//         whitespace,
//         text,
//         eof,
//     };
// };
//
// pub const Tokenizer = struct {
//     buffer: []const u8,
//     index: usize,
//     // pending_invalid_token: ?Token,
//
//     const State = enum {
//         start,
//         heading,
//         whitespace,
//         text,
//     };
//
//     pub fn init(buffer: []const u8) Tokenizer {
//         // Skip the UTF-8 BOM if present
//         return Tokenizer{
//             .buffer = buffer,
//             .index = 0,
//             // .pending_invalid_token = null,
//         };
//     }
//
//     pub fn next(self: *Tokenizer) Token {
//         const start_index = self.index;
//         var state: State = .start;
//         var result = Token{
//             .id = .eof,
//             .start = self.index,
//             .end = undefined,
//         };
//         while (self.index < self.buffer.len) : (self.index += 1) {
//             const c = self.buffer[self.index];
//             debug.print("\nhere {} len: {} char: {} state: {}\n", self.index, self.buffer.len, c, state);
//             switch (state) {
//                 .start => switch (c) {
//                     '#' => {
//                         debug.print("start start\n");
//                         // result.start = self.index + 1;
//                         result.id = .header;
//                         state = .heading;
//                     },
//                     ' ', '\n', '\t', '\r' => {
//                         debug.print("start ws\n");
//                         state = .whitespace;
//                         // break;
//                     },
//                     else => break,
//                 },
//                 .heading => switch (c) {
//                     ' ', '\n', '\t', '\r' => {
//                         debug.print("heading ws\n");
//                         result.id = .header;
//                         state = .whitespace;
//                         break;
//                         // result.id = .whitespace;
//                     },
//                     else => break,
//                 },
//                 .whitespace => switch (c) {
//                     ' ', '\n', '\t', '\r' => {
//                         debug.print("ws\n");
//                         // result.id = .whitespace;
//                         state = .whitespace;
//                     },
//                     'a'...'z', 'A'...'Z', '_' => {
//                         debug.print("text\n");
//                         result.id = .whitespace;
//                         state = .text;
//                         break;
//                     },
//                     else => break,
//                 },
//                 .text => switch (c) {
//                     '\n', '\r' => break,
//                     else => break,
//                 },
//                 else => break,
//             }
//         }
//         debug.print("end\n");
//         result.end = self.index;
//         return result;
//     }
// };
//
// fn testTokenize(source: []const u8, expected_tokens: []const Token.Id) void {
//     var tokenizer = Tokenizer.init(source);
//     for (expected_tokens) |expected_token_id| {
//         const token = tokenizer.next();
//         debug.print("got token: {}\n", token);
//         if (token.id != expected_token_id) {
//             std.debug.panic("expected {}, found {}\n", @tagName(expected_token_id), @tagName(token.id));
//         }
//     }
//     const last_token = tokenizer.next();
//     std.testing.expect(last_token.id == .eof);
// }
//
// test "tokenizer - H1 Header" {
//     testTokenize(
//         \\# Title
//     , [_]Token.Id{
//         .header,
//         .whitespace,
//         .text,
//     });
// }
