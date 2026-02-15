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

fn blankCell(color: u8) u16 {
    return (@as(u16, color) << 8) | @as(u16, ' ');
}

fn vgaMemory() *volatile [WIDTH * HEIGHT]u16 {
    return @as(*volatile [WIDTH * HEIGHT]u16, @ptrFromInt(VGA_ADDRESS));
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

pub fn setColor(color: u8) void {
    screens[active_index].color = color;
}

pub fn activeScreen() usize {
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
    var i: usize = 0;
    const color = screens[active_index].color;
    while (i < WIDTH * HEIGHT) : (i += 1) {
        screens[active_index].buffer[i] = blankCell(color);
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

    const x = screens[active_index].x;
    const y = screens[active_index].y;
    const index = y * WIDTH + x;
    const color = screens[active_index].color;
    const cell = (@as(u16, color) << 8) | @as(u16, c);

    screens[active_index].buffer[index] = cell;
    vgaMemory()[index] = cell;

    screens[active_index].x += 1;
    if (screens[active_index].x >= WIDTH) {
        newLine();
    }

    updateCursor();
}

fn newLine() void {
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
    var row: usize = 1;
    while (row < HEIGHT) : (row += 1) {
        var col: usize = 0;
        while (col < WIDTH) : (col += 1) {
            const from = row * WIDTH + col;
            const to = (row - 1) * WIDTH + col;
            screens[active_index].buffer[to] = screens[active_index].buffer[from];
        }
    }

    const color = screens[active_index].color;
    var col: usize = 0;
    while (col < WIDTH) : (col += 1) {
        const idx = (HEIGHT - 1) * WIDTH + col;
        screens[active_index].buffer[idx] = blankCell(color);
    }
}

pub fn backspace() void {
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
    vgaMemory()[idx] = cell;
    updateCursor();
}

pub fn cursorPosition() usize {
    return screens[active_index].y * WIDTH + screens[active_index].x;
}

fn flushActiveToVga() void {
    var i: usize = 0;
    while (i < WIDTH * HEIGHT) : (i += 1) {
        vgaMemory()[i] = screens[active_index].buffer[i];
    }
}

fn updateCursor() void {
    const position: u16 = @intCast(cursorPosition());

    arch.outb(CURSOR_COMMAND_PORT, 0x0F);
    arch.outb(CURSOR_DATA_PORT, @truncate(position & 0x00FF));
    arch.outb(CURSOR_COMMAND_PORT, 0x0E);
    arch.outb(CURSOR_DATA_PORT, @truncate((position >> 8) & 0x00FF));
}
