const std = @import("std");
const mem = std.mem;
const json = std.json;
const Lexer = @import("lexer.zig").Lexer;
const log = @import("log.zig");

usingnamespace @import("parse_atx_heading.zig");
usingnamespace @import("parse_codeblock.zig");

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
        pub fn jsonStringify(
            value: ID,
            options: json.StringifyOptions,
            out_stream: anytype,
        ) !void {
            try json.stringify(@tagName(value), options, out_stream);
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
                out_stream: anytype,
            ) @TypeOf(out_stream).Error!void {
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
                try out_stream.writeByteNTimes(char, n_chars);
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
                try out_stream.writeByte('\n');
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
                try out_stream.writeByte('\n');
                try whitespace.outputIndent(out_stream);
            }
        }
        try out_stream.writeByte('}');
        return;
    }

    pub fn htmlStringify(
        value: @This(),
        options: StringifyOptions,
        out_stream: anytype,
    ) !void {
        var child_options = options;
        switch (value.ID) {
            .AtxHeading => {
                var lvl = value.Level;
                var text = value.Children.items[0].Value;
                _ = try out_stream.print("<h{}>{}</h{}>", .{ lvl, text, lvl });
                if (child_options.whitespace) |child_whitespace| {
                    if (child_whitespace.separator) {
                        try out_stream.writeByte('\n');
                    }
                }
            },
            .CodeBlock => {
                var lvl = value.Level;
                var text = value.Children.items[0].Value;
                _ = try out_stream.print("<pre><code>{}</code></pre>", .{text});
                if (child_options.whitespace) |child_whitespace| {
                    if (child_whitespace.separator) {
                        try out_stream.writeByte('\n');
                    }
                }
            },
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
                switch (tok.ID) {
                    .Invalid => {},
                    .Text => {},
                    .Whitespace => {
                        try stateCodeBlock(self);
                        // if (mem.eql(u8, tok.string, "\n")) {}
                    },
                    .AtxHeader => {
                        try stateAtxHeader(self);
                    },
                    .EOF => {
                        log.Debug("Found EOF");
                        break;
                    },
                }
            }
        }
    }
};
