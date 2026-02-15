const std = @import("std");

const screens = @import("screens.zig");

const print_buffer_size = 256;

pub const ArgTag = enum {
    str,
    u32,
    i32,
    ch,
};

pub const PrintArg = union(ArgTag) {
    str: []const u8,
    u32: u32,
    i32: i32,
    ch: u8,
};

pub fn write(text: []const u8) void {
    screens.writeString(text);
}

pub fn println(text: []const u8) void {
    screens.writeString(text);
    screens.writeByte('\n');
}

pub fn print(comptime format: []const u8, args: anytype) void {
    writeFormatted(format, args, false);
}

pub fn printlnf(comptime format: []const u8, args: anytype) void {
    writeFormatted(format, args, true);
}

fn writeFormatted(comptime format: []const u8, args: anytype, newline: bool) void {
    std.debug.assert(print_buffer_size >= 64);

    var buffer: [print_buffer_size]u8 = undefined;
    const rendered = std.fmt.bufPrint(&buffer, format, args) catch {
        screens.writeString("[fmt-overflow]");
        if (newline) screens.writeByte('\n');
        return;
    };

    screens.writeString(rendered);
    if (newline) {
        screens.writeByte('\n');
    }
}

// Compatibility layer used by old call sites while migrating to comptime-format printk.
pub fn printf(format: []const u8, args: []const PrintArg) void {
    var arg_index: usize = 0;
    var i: usize = 0;

    while (i < format.len) : (i += 1) {
        if (format[i] != '%') {
            screens.writeByte(format[i]);
            continue;
        }

        if (i + 1 >= format.len) {
            break;
        }

        i += 1;
        const spec = format[i];

        if (spec == '%') {
            screens.writeByte('%');
            continue;
        }

        if (arg_index >= args.len) {
            screens.writeString("<missing>");
            continue;
        }

        const arg = args[arg_index];
        arg_index += 1;

        switch (spec) {
            's' => if (arg == .str) print("{s}", .{arg.str}) else screens.writeString("<bad:%s>"),
            'u' => if (arg == .u32) writeU32(arg.u32) else screens.writeString("<bad:%u>"),
            'd' => if (arg == .i32) writeI32(arg.i32) else screens.writeString("<bad:%d>"),
            'x' => if (arg == .u32) writeHexU32(arg.u32) else screens.writeString("<bad:%x>"),
            'c' => if (arg == .ch) print("{c}", .{arg.ch}) else screens.writeString("<bad:%c>"),
            else => {
                screens.writeByte('%');
                screens.writeByte(spec);
            },
        }
    }
}

pub fn writeHexU32(value: u32) void {
    print("0x{x}", .{value});
}

pub fn writeU32(value: u32) void {
    print("{d}", .{value});
}

pub fn writeI32(value: i32) void {
    print("{d}", .{value});
}

fn readAsciiAt(index: usize) u8 {
    return @truncate(screens.testCell(index) & 0x00FF);
}

test "write and println" {
    screens.init();
    write("ab");
    println("cd");

    try std.testing.expectEqual(@as(u8, 'a'), readAsciiAt(0));
    try std.testing.expectEqual(@as(u8, 'b'), readAsciiAt(1));
    try std.testing.expectEqual(@as(u8, 'c'), readAsciiAt(2));
    try std.testing.expectEqual(@as(u8, 'd'), readAsciiAt(3));
    try std.testing.expectEqual(@as(usize, screens.WIDTH), screens.cursorPosition());
}

test "std fmt-backed print variants" {
    screens.init();
    print("{s}-{d}-{x}-{c}", .{ "ok", @as(i32, -4), @as(u32, 0x2A), @as(u8, 'Z') });
    try std.testing.expectEqual(@as(u8, 'o'), readAsciiAt(0));
    try std.testing.expectEqual(@as(u8, 'k'), readAsciiAt(1));

    printlnf(" value={d}", .{@as(u32, 99)});
    try std.testing.expectEqual(@as(usize, screens.WIDTH), screens.cursorPosition());
}

test "legacy printf compatibility" {
    screens.init();
    printf("%s %u %d %x %c %% %q", &[_]PrintArg{
        .{ .str = "ok" },
        .{ .u32 = 12 },
        .{ .i32 = -3 },
        .{ .u32 = 0x2A },
        .{ .ch = 'Z' },
    });

    try std.testing.expectEqual(@as(u8, 'o'), readAsciiAt(0));
    try std.testing.expectEqual(@as(u8, 'k'), readAsciiAt(1));

    screens.init();
    printf("%u %s", &[_]PrintArg{.{ .str = "bad" }});
    try std.testing.expectEqual(@as(u8, '<'), readAsciiAt(0));

    screens.init();
    printf("%u %u", &[_]PrintArg{.{ .u32 = 1 }});
    try std.testing.expectEqual(@as(u8, '1'), readAsciiAt(0));
    try std.testing.expectEqual(@as(u8, '<'), readAsciiAt(2));
}
