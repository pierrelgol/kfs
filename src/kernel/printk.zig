const screens = @import("screens.zig");

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
            's' => {
                if (arg == .str) {
                    screens.writeString(arg.str);
                } else {
                    screens.writeString("<bad:%s>");
                }
            },
            'u' => {
                if (arg == .u32) {
                    writeU32(arg.u32);
                } else {
                    screens.writeString("<bad:%u>");
                }
            },
            'd' => {
                if (arg == .i32) {
                    writeI32(arg.i32);
                } else {
                    screens.writeString("<bad:%d>");
                }
            },
            'x' => {
                if (arg == .u32) {
                    writeHexU32(arg.u32);
                } else {
                    screens.writeString("<bad:%x>");
                }
            },
            'c' => {
                if (arg == .ch) {
                    screens.writeByte(arg.ch);
                } else {
                    screens.writeString("<bad:%c>");
                }
            },
            else => {
                screens.writeByte('%');
                screens.writeByte(spec);
            },
        }
    }
}

pub fn writeHexU32(value: u32) void {
    screens.writeString("0x");
    var shift: u5 = 28;
    while (true) {
        const nibble: u4 = @truncate((value >> shift) & 0xF);
        if (nibble < 10) {
            screens.writeByte('0' + nibble);
        } else {
            screens.writeByte('a' + (nibble - 10));
        }

        if (shift == 0) {
            break;
        }
        shift -= 4;
    }
}

pub fn writeU32(value: u32) void {
    if (value == 0) {
        screens.writeByte('0');
        return;
    }

    var digits: [10]u8 = undefined;
    var count: usize = 0;
    var n = value;

    while (n > 0) {
        digits[count] = @intCast('0' + (n % 10));
        n /= 10;
        count += 1;
    }

    while (count > 0) {
        count -= 1;
        screens.writeByte(digits[count]);
    }
}

pub fn writeI32(value: i32) void {
    if (value < 0) {
        screens.writeByte('-');
        const positive: u32 = @intCast(-value);
        writeU32(positive);
        return;
    }
    writeU32(@intCast(value));
}
