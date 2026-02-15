const builtin = @import("builtin");
const std = @import("std");

const arch = @import("arch.zig");

pub const WIDTH: usize = 80;
pub const HEIGHT: usize = 25;
pub const SCREEN_COUNT: usize = 3;

const VGA_ADDRESS: usize = 0xB8000;
const CURSOR_COMMAND_PORT: u16 = 0x3D4;
const CURSOR_DATA_PORT: u16 = 0x3D5;

const Screen = struct {
    buffer: [WIDTH * HEIGHT]u16,
    x: usize,
    y: usize,
    color: u8,
};

var screens: [SCREEN_COUNT]Screen = undefined;
var active_index: usize = 0;

var test_vga: [WIDTH * HEIGHT]u16 = [_]u16{0} ** (WIDTH * HEIGHT);
var test_cursor_position: usize = 0;

fn blankCell(attr: u8) u16 {
    return (@as(u16, attr) << 8) | @as(u16, ' ');
}

fn vgaMemory() *volatile [WIDTH * HEIGHT]u16 {
    return @as(*volatile [WIDTH * HEIGHT]u16, @ptrFromInt(VGA_ADDRESS));
}

fn setVgaCell(index: usize, value: u16) void {
    std.debug.assert(index < WIDTH * HEIGHT);

    if (builtin.is_test) {
        test_vga[index] = value;
        return;
    }

    vgaMemory()[index] = value;
}

fn getVgaCell(index: usize) u16 {
    std.debug.assert(index < WIDTH * HEIGHT);

    if (builtin.is_test) {
        return test_vga[index];
    }

    return vgaMemory()[index];
}

pub fn init() void {
    var i: usize = 0;
    while (i < SCREEN_COUNT) : (i += 1) {
        screens[i].x = 0;
        screens[i].y = 0;
        screens[i].color = 0x0F;

        var j: usize = 0;
        while (j < WIDTH * HEIGHT) : (j += 1) {
            screens[i].buffer[j] = blankCell(screens[i].color);
        }
    }

    active_index = 0;
    flushActiveToVga();
    updateCursor();
}

pub fn setColor(attr: u8) void {
    std.debug.assert(active_index < SCREEN_COUNT);
    screens[active_index].color = attr;
}

pub fn color() u8 {
    std.debug.assert(active_index < SCREEN_COUNT);
    return screens[active_index].color;
}

pub fn activeScreen() usize {
    std.debug.assert(active_index < SCREEN_COUNT);
    return active_index;
}

pub fn switchTo(index: usize) void {
    if (index >= SCREEN_COUNT) {
        return;
    }
    active_index = index;
    flushActiveToVga();
    updateCursor();
}

pub fn clear() void {
    std.debug.assert(active_index < SCREEN_COUNT);

    var i: usize = 0;
    const cur_color = screens[active_index].color;
    while (i < WIDTH * HEIGHT) : (i += 1) {
        screens[active_index].buffer[i] = blankCell(cur_color);
    }
    screens[active_index].x = 0;
    screens[active_index].y = 0;
    flushActiveToVga();
    updateCursor();
}

pub fn writeString(text: []const u8) void {
    for (text) |c| {
        writeByte(c);
    }
}

pub fn writeByte(c: u8) void {
    if (c == '\n') {
        newLine();
        return;
    }

    std.debug.assert(active_index < SCREEN_COUNT);

    const x = screens[active_index].x;
    const y = screens[active_index].y;
    std.debug.assert(x < WIDTH);
    std.debug.assert(y < HEIGHT);

    writeByteAt(x, y, c);

    screens[active_index].x += 1;
    if (screens[active_index].x >= WIDTH) {
        newLine();
        return;
    }

    updateCursor();
}

pub fn writeByteAt(x: usize, y: usize, c: u8) void {
    std.debug.assert(active_index < SCREEN_COUNT);
    std.debug.assert(x < WIDTH);
    std.debug.assert(y < HEIGHT);

    const index = y * WIDTH + x;
    const cell = (@as(u16, screens[active_index].color) << 8) | @as(u16, c);
    screens[active_index].buffer[index] = cell;
    setVgaCell(index, cell);
}

pub fn setCursor(x: usize, y: usize) void {
    std.debug.assert(active_index < SCREEN_COUNT);
    std.debug.assert(x < WIDTH);
    std.debug.assert(y < HEIGHT);

    screens[active_index].x = x;
    screens[active_index].y = y;
    updateCursor();
}

pub fn cursorX() usize {
    std.debug.assert(active_index < SCREEN_COUNT);
    return screens[active_index].x;
}

pub fn cursorY() usize {
    std.debug.assert(active_index < SCREEN_COUNT);
    return screens[active_index].y;
}

fn newLine() void {
    std.debug.assert(active_index < SCREEN_COUNT);

    screens[active_index].x = 0;
    screens[active_index].y += 1;

    if (screens[active_index].y >= HEIGHT) {
        scroll();
        screens[active_index].y = HEIGHT - 1;
    }

    flushActiveToVga();
    updateCursor();
}

fn scroll() void {
    std.debug.assert(active_index < SCREEN_COUNT);

    var row: usize = 1;
    while (row < HEIGHT) : (row += 1) {
        var col: usize = 0;
        while (col < WIDTH) : (col += 1) {
            const from = row * WIDTH + col;
            const to = (row - 1) * WIDTH + col;
            screens[active_index].buffer[to] = screens[active_index].buffer[from];
        }
    }

    const cur_color = screens[active_index].color;
    var col: usize = 0;
    while (col < WIDTH) : (col += 1) {
        const idx = (HEIGHT - 1) * WIDTH + col;
        screens[active_index].buffer[idx] = blankCell(cur_color);
    }
}

pub fn backspace() void {
    std.debug.assert(active_index < SCREEN_COUNT);

    if (screens[active_index].x == 0 and screens[active_index].y == 0) {
        return;
    }

    if (screens[active_index].x == 0) {
        screens[active_index].y -= 1;
        screens[active_index].x = WIDTH - 1;
    } else {
        screens[active_index].x -= 1;
    }

    const idx = screens[active_index].y * WIDTH + screens[active_index].x;
    const cell = blankCell(screens[active_index].color);
    screens[active_index].buffer[idx] = cell;
    setVgaCell(idx, cell);
    updateCursor();
}

pub fn cursorPosition() usize {
    std.debug.assert(active_index < SCREEN_COUNT);
    std.debug.assert(screens[active_index].x < WIDTH);
    std.debug.assert(screens[active_index].y < HEIGHT);
    return screens[active_index].y * WIDTH + screens[active_index].x;
}

fn flushActiveToVga() void {
    var i: usize = 0;
    while (i < WIDTH * HEIGHT) : (i += 1) {
        setVgaCell(i, screens[active_index].buffer[i]);
    }
}

fn updateCursor() void {
    const position: u16 = @intCast(cursorPosition());

    if (builtin.is_test) {
        test_cursor_position = position;
        return;
    }

    arch.outb(CURSOR_COMMAND_PORT, 0x0F);
    arch.outb(CURSOR_DATA_PORT, @truncate(position & 0x00FF));
    arch.outb(CURSOR_COMMAND_PORT, 0x0E);
    arch.outb(CURSOR_DATA_PORT, @truncate((position >> 8) & 0x00FF));
}

pub fn testCell(index: usize) u16 {
    std.debug.assert(builtin.is_test);
    return getVgaCell(index);
}

pub fn peekCell(index: usize) u16 {
    return getVgaCell(index);
}

pub fn testCursorPosition() usize {
    std.debug.assert(builtin.is_test);
    return test_cursor_position;
}

test "init clears all screens and sets default cursor" {
    init();
    try std.testing.expectEqual(@as(usize, 0), activeScreen());
    try std.testing.expectEqual(@as(usize, 0), cursorPosition());
    try std.testing.expectEqual(blankCell(0x0F), testCell(0));
    try std.testing.expectEqual(@as(usize, 0), testCursorPosition());
}

test "write string and newline update cursor and cells" {
    init();
    setColor(0x1E);
    writeString("A\nB");

    try std.testing.expectEqual((@as(u16, 0x1E) << 8) | @as(u16, 'A'), testCell(0));
    try std.testing.expectEqual((@as(u16, 0x1E) << 8) | @as(u16, 'B'), testCell(WIDTH));
    try std.testing.expectEqual(@as(usize, WIDTH + 1), cursorPosition());
}

test "switch screens preserves independent buffers" {
    init();
    writeString("X");
    switchTo(1);
    writeString("Y");

    try std.testing.expectEqual((@as(u16, 0x0F) << 8) | @as(u16, 'Y'), testCell(0));

    switchTo(0);
    try std.testing.expectEqual((@as(u16, 0x0F) << 8) | @as(u16, 'X'), testCell(0));
}

test "scroll moves lines up" {
    init();

    var row: usize = 0;
    while (row < HEIGHT) : (row += 1) {
        writeByte(@intCast('a' + @as(u8, @intCast(row % 26))));
        writeByte('\n');
    }

    const top = testCell(0) & 0x00FF;
    try std.testing.expectEqual(@as(u16, 'b'), top);
}

test "backspace from middle and line start" {
    init();
    writeString("AB");
    backspace();
    try std.testing.expectEqual(@as(usize, 1), cursorPosition());

    writeByte('\n');
    backspace();
    try std.testing.expectEqual(@as(usize, WIDTH - 1), cursorPosition());
}

test "set cursor and write byte at explicit location" {
    init();
    setColor(0x2F);
    writeByteAt(10, 3, 'Z');
    setCursor(10, 3);
    try std.testing.expectEqual(@as(usize, 10), cursorX());
    try std.testing.expectEqual(@as(usize, 3), cursorY());
    try std.testing.expectEqual((@as(u16, 0x2F) << 8) | @as(u16, 'Z'), testCell(3 * WIDTH + 10));
}
