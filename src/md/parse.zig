const std = @import("std");
const mem = std.mem;
const json = std.json;
const Lexer = @import("lexer.zig").Lexer;
const log = @import("log.zig");
const ttyCode = log.logger.TTY.Code;

usingnamespace @import("parse_atx_heading.zig");
usingnamespace @import("parse_codeblock.zig");
usingnamespace @import("parse_list.zig");

/// Function prototype for a State Transition in the Parser
pub const StateTransition = fn (lexer: *Lexer) anyerror!?AstNode;

pub const Node = struct {
    ID: ID,
    Value: ?[]const u8,

    PositionStart: Position,
    PositionEnd: Position,

    Children: std.ArrayList(Node),

    Level: u32,

    pub const Position = struct {
        Line: u32,
        Column: u32,
        Offset: u32,
    };

    pub const ID = enum {
        AtxHeading,
        Text,
        CodeBlock,
        BulletList,
        ListItem,
        pub fn jsonStringify(
            value: ID,
            options: json.StringifyOptions,
            writer: anytype,
        ) !void {
            try json.stringify(@tagName(value), options, writer);
        }
    };

    pub const StringifyOptions = struct {
        pub const Whitespace = struct {
            /// How many indentation levels deep are we?
            indent_level: usize = 0,

            /// What character(s) should be used for indentation?
            indent: union(enum) {
                Space: u8,
                Tab: void,
            } = .{ .Space = 4 },

            /// Newline after each element
            separator: bool = true,

            pub fn outputIndent(
                whitespace: @This(),
                writer: anytype,
            ) @TypeOf(writer).Error!void {
                var char: u8 = undefined;
                var n_chars: usize = undefined;
                switch (whitespace.indent) {
                    .Space => |n_spaces| {
                        char = ' ';
                        n_chars = n_spaces;
                    },
                    .Tab => {
                        char = '\t';
                        n_chars = 1;
                    },
                }
                n_chars *= whitespace.indent_level;
                try writer.writeByteNTimes(char, n_chars);
            }
        };

        /// Controls the whitespace emitted
        whitespace: ?Whitespace = null,

        string: StringOptions = StringOptions{ .String = .{} },

        /// Should []u8 be serialised as a string? or an array?
        pub const StringOptions = union(enum) {
            Array,
            String: StringOutputOptions,

            /// String output options
            const StringOutputOptions = struct {
                /// Should '/' be escaped in strings?
                escape_solidus: bool = false,

                /// Should unicode characters be escaped in strings?
                escape_unicode: bool = false,
            };
        };
    };

    pub fn deinit(self: @This()) void {
        self.Children.deinit();
    }

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
                try writer.writeByte('\n');
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
                    for (boop.items) |item, i| {
                        try json.stringify(item, child_options, writer);
                        if (i < boop.items.len - 1) {
                            try writer.writeByte(',');
                        }
                    }
                    _ = try writer.write("]");
                }
            }
        }
        if (field_output) {
            if (options.whitespace) |whitespace| {
                try writer.writeByte('\n');
                try whitespace.outputIndent(writer);
            }
        }
        try writer.writeByte('}');
        return;
    }

    pub fn htmlStringify(
        value: @This(),
        options: StringifyOptions,
        writer: anytype,
    ) !void {
        var child_options = options;
        switch (value.ID) {
            .AtxHeading => {
                var lvl = value.Level;
                var text = value.Children.items[0].Value;
                _ = try writer.print("<h{}>{}</h{}>", .{ lvl, text, lvl });
                if (child_options.whitespace) |child_whitespace| {
                    if (child_whitespace.separator) {
                        try writer.writeByte('\n');
                    }
                }
            },
            .CodeBlock => {
                var lvl = value.Level;
                var text = value.Children.items[0].Value;
                _ = try writer.print("<pre><code>{}</code></pre>", .{text});
                if (child_options.whitespace) |child_whitespace| {
                    if (child_whitespace.separator) {
                        try writer.writeByte('\n');
                    }
                }
            },
            .BulletList => {
                _ = try writer.writeAll("<ul>\n<li>\n");
                for (value.Children.items[0].Children.items) |item| {
                    _ = try writer.print("<p>{}</p>\n", .{item.Value});
                }
                _ = try writer.writeAll("</li>\n</ul>\n");
            },
            .ListItem => {},
            .Text => {},
        }
    }
};

/// A non-stream Markdown parser which constructs a tree of Nodes
pub const Parser = struct {
    allocator: *mem.Allocator,

    root: std.ArrayList(Node),
    state: State,
    lex: Lexer,

    pub const State = enum {
        Start,
        AtxHeader,
        CodeBlock,
    };

    pub fn init(
        allocator: *mem.Allocator,
    ) Parser {
        return Parser{
            .allocator = allocator,
            .state = .Start,
            .root = std.ArrayList(Node).init(allocator),
            .lex = undefined,
        };
    }

    pub fn deinit(self: *Parser) void {
        for (self.root.items) |item| {
            for (item.Children.items) |subchild| {
                if (subchild.Value) |val2| {
                    self.allocator.free(val2);
                }
                subchild.deinit();
            }
            if (item.Value) |val| {
                self.allocator.free(val);
            }
            item.deinit();
        }
        self.root.deinit();
        self.lex.deinit();
    }

    pub fn parse(self: *Parser, input: []const u8) !void {
        self.lex = try Lexer.init(self.allocator, input);
        while (true) {
            if (try self.lex.next()) |tok| {
                self.lex.tokenIndex = tok.index;
                log.Debugf("{}parsing next token id: {} index: {} str: '{Z}' tokenIndex: {}{}\n", .{ ttyCode(.Cyan), tok.ID, tok.index, tok.string, self.lex.tokenIndex, ttyCode(.Reset) });
                switch (tok.ID) {
                    .BulletListMarker => {
                        try stateBulletList(self);
                    },
                    .Whitespace => {
                        try stateCodeBlock(self);
                    },
                    .AtxHeader => {
                        try stateAtxHeader(self);
                    },
                    .EOF => {
                        log.Debug("Found EOF");
                        break;
                    },
                    .Newline => {},
                    .Invalid => {},
                    .Text => {},
                }
            }
        }
    }
};
