const builtin = @import("builtin");
const std = @import("std");

const arch = @import("arch.zig");
const keyboard = @import("keyboard.zig");
const printk = @import("printk.zig");
const screens = @import("screens.zig");
const selftest = @import("selftest.zig");
const stack_trace = @import("stack_trace.zig");

const MAX_LINE: usize = 128;
const PROMPT: []const u8 = "kfs> ";
const INPUT_CAPACITY: usize = @min(MAX_LINE, screens.WIDTH - PROMPT.len);

comptime {
    if (PROMPT.len >= screens.WIDTH) {
        @compileError("shell prompt must fit in one VGA line");
    }
}

const LineState = struct {
    buf: [MAX_LINE]u8 = undefined,
    len: usize = 0,
    cursor: usize = 0,
    rendered_len: usize = 0,
    row: usize = 0,
};

var line: LineState = .{};

pub fn init() void {
    line.len = 0;
    line.cursor = 0;
    line.rendered_len = 0;
    line.row = screens.cursorY();
}

pub fn printPrompt() void {
    if (screens.cursorX() != 0) {
        screens.writeByte('\n');
    }

    line.row = screens.cursorY();
    line.len = 0;
    line.cursor = 0;
    line.rendered_len = 0;

    printk.write(PROMPT);
    syncCursor();
}

pub fn handleKeyEvent(event: keyboard.KeyEvent) void {
    if (!event.pressed) {
        return;
    }

    if (selftest.isActive()) {
        if (event.kind == .control and event.control == .esc) {
            selftest.cancel();
        }
        return;
    }

    switch (event.kind) {
        .function => handleFunction(event.function.?),
        .control => handleControl(event.control.?),
        .char => insertChar(event.ascii),
        .unknown => {},
    }
}

fn handleFunction(key: keyboard.FunctionKey) void {
    switch (key) {
        .f1 => screens.switchTo(0),
        .f2 => screens.switchTo(1),
        .f3 => screens.switchTo(2),
        .f12 => {
            selftest.start(.panic_on_fail);
        },
        else => {},
    }
}

fn handleControl(key: keyboard.ControlKey) void {
    switch (key) {
        .backspace => deleteBackspace(),
        .delete => deleteAtCursor(),
        .left => moveLeft(),
        .right => moveRight(),
        .home => moveHome(),
        .end => moveEnd(),
        .enter => submitLine(),
        .esc => {},
        .tab => insertChar(' '),
    }
}

fn insertChar(c: u8) void {
    if (c < 32 or c > 126) {
        return;
    }

    std.debug.assert(line.cursor <= line.len);
    if (line.len >= MAX_LINE) {
        return;
    }

    if (line.len >= INPUT_CAPACITY) {
        return;
    }

    var i = line.len;
    while (i > line.cursor) : (i -= 1) {
        line.buf[i] = line.buf[i - 1];
    }

    line.buf[line.cursor] = c;
    line.len += 1;
    line.cursor += 1;
    redrawLine();
}

fn deleteBackspace() void {
    if (line.cursor == 0 or line.len == 0) {
        return;
    }

    var i = line.cursor - 1;
    while (i + 1 < line.len) : (i += 1) {
        line.buf[i] = line.buf[i + 1];
    }

    line.cursor -= 1;
    line.len -= 1;
    redrawLine();
}

fn deleteAtCursor() void {
    if (line.cursor >= line.len) {
        return;
    }

    var i = line.cursor;
    while (i + 1 < line.len) : (i += 1) {
        line.buf[i] = line.buf[i + 1];
    }

    line.len -= 1;
    redrawLine();
}

fn moveLeft() void {
    if (line.cursor == 0) return;
    line.cursor -= 1;
    syncCursor();
}

fn moveRight() void {
    if (line.cursor >= line.len) return;
    line.cursor += 1;
    syncCursor();
}

fn moveHome() void {
    line.cursor = 0;
    syncCursor();
}

fn moveEnd() void {
    line.cursor = line.len;
    syncCursor();
}

fn submitLine() void {
    screens.writeByte('\n');

    const input = line.buf[0..line.len];
    execute(input);
    printPrompt();
}

pub fn execute(line_in: []const u8) void {
    if (equals(line_in, "help")) {
        printk.println("commands: help clear stack screen <n> selftest selftest stop echo <txt> halt reboot shutdown");
        return;
    }

    if (equals(line_in, "clear")) {
        screens.clear();
        return;
    }

    if (equals(line_in, "stack")) {
        stack_trace.dumpKernelStack();
        return;
    }

    if (startsWith(line_in, "screen ")) {
        if (parseSingleDigit(line_in[7..])) |idx| {
            if (idx < screens.SCREEN_COUNT) {
                screens.switchTo(idx);
                return;
            }
        }
        printk.println("usage: screen 0|1|2");
        return;
    }

    if (equals(line_in, "selftest")) {
        selftest.start(.panic_on_fail);
        return;
    }

    if (equals(line_in, "selftest stop")) {
        selftest.cancel();
        return;
    }

    if (startsWith(line_in, "echo ")) {
        printk.printlnf("{s}", .{line_in[5..]});
        return;
    }

    if (equals(line_in, "halt")) {
        printk.println("halting...");
        arch.haltForever();
    }

    if (equals(line_in, "reboot")) {
        printk.println("rebooting...");
        reboot();
        arch.haltForever();
    }

    if (equals(line_in, "shutdown")) {
        printk.println("shutting down...");
        shutdown();
        return;
    }

    if (line_in.len != 0) {
        printk.printlnf("unknown command: {s}", .{line_in});
    }
}

fn redrawLine() void {
    std.debug.assert(line.len <= MAX_LINE);
    std.debug.assert(line.len <= INPUT_CAPACITY);
    std.debug.assert(line.cursor <= line.len);
    std.debug.assert(line.row < screens.HEIGHT);

    const max_len = if (line.rendered_len > line.len) line.rendered_len else line.len;

    var i: usize = 0;
    while (i < max_len) : (i += 1) {
        const c: u8 = if (i < line.len) line.buf[i] else ' ';
        screens.writeByteAt(PROMPT.len + i, line.row, c);
    }

    line.rendered_len = line.len;
    syncCursor();
}

fn syncCursor() void {
    std.debug.assert(line.len <= INPUT_CAPACITY);
    std.debug.assert(line.cursor <= line.len);
    std.debug.assert(line.row < screens.HEIGHT);

    const x = PROMPT.len + line.cursor;
    std.debug.assert(x < screens.WIDTH);
    screens.setCursor(x, line.row);
}

fn parseSingleDigit(input: []const u8) ?usize {
    if (input.len != 1) return null;
    if (input[0] < '0' or input[0] > '9') return null;
    return @intCast(input[0] - '0');
}

fn reboot() void {
    while ((arch.inb(0x64) & 0x02) != 0) {}
    arch.outb(0x64, 0xFE);
}

fn shutdown() void {
    // Common QEMU/ACPI/legacy power-off ports.
    arch.outw(0x604, 0x2000);
    arch.outw(0xB004, 0x2000);
    arch.outw(0x4004, 0x3400);

    if (builtin.is_test) {
        return;
    }

    arch.haltForever();
}

fn equals(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    var i: usize = 0;
    while (i < a.len) : (i += 1) {
        if (a[i] != b[i]) return false;
    }
    return true;
}

fn startsWith(text: []const u8, prefix: []const u8) bool {
    if (text.len < prefix.len) return false;
    var i: usize = 0;
    while (i < prefix.len) : (i += 1) {
        if (text[i] != prefix[i]) return false;
    }
    return true;
}

test "line editing insert cursor move and delete" {
    screens.init();
    init();
    printPrompt();

    handleKeyEvent(.{ .kind = .char, .pressed = true, .ascii = 'a', .function = null, .control = null, .scancode = 0x1E });
    handleKeyEvent(.{ .kind = .char, .pressed = true, .ascii = 'b', .function = null, .control = null, .scancode = 0x30 });
    handleKeyEvent(.{ .kind = .control, .pressed = true, .ascii = 0, .function = null, .control = .left, .scancode = 0x4B });
    handleKeyEvent(.{ .kind = .char, .pressed = true, .ascii = 'X', .function = null, .control = null, .scancode = 0x2D });

    const idx = PROMPT.len;
    try std.testing.expectEqual(@as(u16, 'a'), screens.testCell(idx) & 0x00FF);
    try std.testing.expectEqual(@as(u16, 'X'), screens.testCell(idx + 1) & 0x00FF);
    try std.testing.expectEqual(@as(u16, 'b'), screens.testCell(idx + 2) & 0x00FF);

    handleKeyEvent(.{ .kind = .control, .pressed = true, .ascii = 0, .function = null, .control = .delete, .scancode = 0x53 });
    try std.testing.expectEqual(@as(u16, 'a'), screens.testCell(idx) & 0x00FF);
    try std.testing.expectEqual(@as(u16, 'X'), screens.testCell(idx + 1) & 0x00FF);
}

test "command execution selftest stop path" {
    screens.init();
    selftest.start(.collect);
    try std.testing.expect(selftest.isActive());

    execute("selftest stop");
    try std.testing.expect(!selftest.isActive());
}

test "command execution help echo clear screen and unknown" {
    screens.init();
    init();

    execute("help");
    try std.testing.expectEqual(@as(u16, 'c'), screens.testCell(0) & 0x00FF);

    screens.clear();
    execute("echo zig");
    try std.testing.expectEqual(@as(u16, 'z'), screens.testCell(0) & 0x00FF);
    try std.testing.expectEqual(@as(u16, 'g'), screens.testCell(2) & 0x00FF);

    execute("clear");
    try std.testing.expectEqual(@as(usize, 0), screens.cursorPosition());
    try std.testing.expectEqual(@as(u16, ' '), screens.testCell(0) & 0x00FF);

    execute("screen 1");
    try std.testing.expectEqual(@as(usize, 1), screens.activeScreen());

    execute("screen 9");
    try std.testing.expectEqual(@as(usize, 1), screens.activeScreen());
    try std.testing.expectEqual(@as(u16, 'u'), screens.testCell(0) & 0x00FF);

    screens.clear();
    execute("stack");
    try std.testing.expectEqual(@as(u16, 's'), screens.testCell(0) & 0x00FF);

    screens.clear();
    execute("shutdown");
    try std.testing.expectEqual(@as(u16, 0x2000), arch.testGetOutW(0x604));
    try std.testing.expectEqual(@as(u16, 0x2000), arch.testGetOutW(0xB004));
    try std.testing.expectEqual(@as(u16, 0x3400), arch.testGetOutW(0x4004));

    screens.clear();
    execute("wat");
    try std.testing.expectEqual(@as(u16, 'u'), screens.testCell(0) & 0x00FF);
}

test "command helpers parse single digit and prefix checks" {
    try std.testing.expectEqual(@as(?usize, 0), parseSingleDigit("0"));
    try std.testing.expectEqual(@as(?usize, 9), parseSingleDigit("9"));
    try std.testing.expectEqual(@as(?usize, null), parseSingleDigit(""));
    try std.testing.expectEqual(@as(?usize, null), parseSingleDigit("12"));
    try std.testing.expectEqual(@as(?usize, null), parseSingleDigit("x"));

    try std.testing.expect(equals("abc", "abc"));
    try std.testing.expect(!equals("abc", "ab"));
    try std.testing.expect(!equals("abc", "abd"));

    try std.testing.expect(startsWith("screen 1", "screen "));
    try std.testing.expect(!startsWith("screen", "screen "));
    try std.testing.expect(!startsWith("echo", "stack"));
}
