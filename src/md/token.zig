const std = @import("std");
const mem = std.mem;
const json = std.json;

const Lexer = @import("lexer.zig").Lexer;

const TokenIds = [_][]const u8{
    "Invalid",
    "Whitespace",
    "Newline",
    "Text",
    "AtxHeader",
    "BulletListMarker",
    "EOF",
};

pub const TokenId = enum {
    Invalid,
    Whitespace,
    Newline,
    Text,
    AtxHeader,
    BulletListMarker,
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
        writer: anytype,
    ) !void {
        try json.stringify(self.string(), options, writer);
    }
};

pub const Token = struct {
    index: usize,
    ID: TokenId,
    startOffset: u32,
    endOffset: u32,
    string: []const u8,
    lineNumber: u32,
    column: u32,

    pub fn jsonStringify(
        value: @This(),
        options: json.StringifyOptions,
        writer: anytype,
    ) !void {
        try writer.writeByte('{');
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
                try writer.writeByte(',');
            }
            if (child_options.whitespace) |child_whitespace| {
                // FIXME: all this to remove this line...
                // try writer.writeByte('\n');
                try child_whitespace.outputIndent(writer);
            }
            try json.stringify(Field.name, options, writer);
            try writer.writeByte(':');
            if (child_options.whitespace) |child_whitespace| {
                if (child_whitespace.separator) {
                    try writer.writeByte(' ');
                }
            }
            if (comptime !mem.eql(u8, Field.name, "Children")) {
                try json.stringify(@field(value, Field.name), child_options, writer);
            } else {
                var boop = @field(value, Field.name);
                if (boop.items.len == 0) {
                    _ = try writer.writeAll("[]");
                } else {
                    _ = try writer.write("[");
                    for (boop.items) |item| {
                        try json.stringify(item, child_options, writer);
                    }
                    _ = try writer.write("]");
                }
            }
        }
        if (field_output) {
            if (options.whitespace) |whitespace| {
                // FIXME: all this to remove this line...
                // try writer.writeByte('\n');
                try whitespace.outputIndent(writer);
            }
        }
        try writer.writeByte(' ');
        try writer.writeByte('}');
        return;
    }
};
