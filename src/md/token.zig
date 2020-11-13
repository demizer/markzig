const std = @import("std");
const mem = std.mem;
const json = std.json;

const Lexer = @import("lexer.zig").Lexer;

const TokenIds = [_][]const u8{
    "Invalid",
    "Whitespace",
    "Text",
    "AtxHeader",
    "EOF",
};

pub const TokenId = enum {
    Invalid,
    Whitespace,
    Text,
    AtxHeader,
    EOF,

    pub fn string(self: TokenId) []const u8 {
        const m = @enumToInt(self);
        if (@enumToInt(TokenId.Invalid) <= m and m <= @enumToInt(TokenId.EOF)) {
            return TokenIds[m];
        }
        unreachable;
    }

    pub fn jsonStringify(
        self: @This(),
        options: json.StringifyOptions,
        out_stream: anytype,
    ) !void {
        try json.stringify(self.string(), options, out_stream);
    }
};

pub const Token = struct {
    ID: TokenId,
    startOffset: u32,
    endOffset: u32,
    string: []const u8,
    lineNumber: u32,
    column: u32,

    pub fn jsonStringify(
        value: @This(),
        options: json.StringifyOptions,
        out_stream: anytype,
    ) !void {
        try out_stream.writeByte('{');
        const T = @TypeOf(value);
        const S = @typeInfo(T).Struct;
        comptime var field_output = false;
        var child_options = options;
        if (child_options.whitespace) |*child_whitespace| {
            child_whitespace.indent_level += 1;
        }
        inline for (S.fields) |Field, field_i| {
            if (Field.field_type == void) continue;

            if (!field_output) {
                field_output = true;
            } else {
                try out_stream.writeByte(',');
            }
            if (child_options.whitespace) |child_whitespace| {
                // FIXME: all this to remove this line...
                // try out_stream.writeByte('\n');
                try child_whitespace.outputIndent(out_stream);
            }
            try json.stringify(Field.name, options, out_stream);
            try out_stream.writeByte(':');
            if (child_options.whitespace) |child_whitespace| {
                if (child_whitespace.separator) {
                    try out_stream.writeByte(' ');
                }
            }
            if (comptime !mem.eql(u8, Field.name, "Children")) {
                try json.stringify(@field(value, Field.name), child_options, out_stream);
            } else {
                var boop = @field(value, Field.name);
                if (boop.items.len == 0) {
                    _ = try out_stream.writeAll("[]");
                } else {
                    _ = try out_stream.write("[");
                    for (boop.items) |item| {
                        try json.stringify(item, child_options, out_stream);
                    }
                    _ = try out_stream.write("]");
                }
            }
        }
        if (field_output) {
            if (options.whitespace) |whitespace| {
                // FIXME: all this to remove this line...
                // try out_stream.writeByte('\n');
                try whitespace.outputIndent(out_stream);
            }
        }
        try out_stream.writeByte(' ');
        try out_stream.writeByte('}');
        return;
    }
};

pub const TokenRule = fn (lexer: *Lexer) anyerror!?Token;
