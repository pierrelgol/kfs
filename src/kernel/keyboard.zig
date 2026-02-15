const std = @import("std");

const arch = @import("arch.zig");
const screens = @import("screens.zig");

const DATA_PORT: u16 = 0x60;
const STATUS_PORT: u16 = 0x64;

pub const KeyEvent = struct {
    ascii: u8,
    pressed: bool,
};

pub fn poll() ?KeyEvent {
    std.debug.assert(screens.SCREEN_COUNT >= 3);

    if ((arch.inb(STATUS_PORT) & 0x01) == 0) {
        return null;
    }

    const scancode = arch.inb(DATA_PORT);
    if ((scancode & 0x80) != 0) {
        return KeyEvent{ .ascii = 0, .pressed = false };
    }

    if (scancode == 0x3B) {
        screens.switchTo(0);
        return KeyEvent{ .ascii = 0, .pressed = true };
    }
    if (scancode == 0x3C) {
        screens.switchTo(1);
        return KeyEvent{ .ascii = 0, .pressed = true };
    }
    if (scancode == 0x3D) {
        screens.switchTo(2);
        return KeyEvent{ .ascii = 0, .pressed = true };
    }

    return KeyEvent{ .ascii = translateSet1(scancode), .pressed = true };
}

pub fn translateSet1(scancode: u8) u8 {
    return switch (scancode) {
        0x02 => '1',
        0x03 => '2',
        0x04 => '3',
        0x05 => '4',
        0x06 => '5',
        0x07 => '6',
        0x08 => '7',
        0x09 => '8',
        0x0A => '9',
        0x0B => '0',
        0x0C => '-',
        0x0D => '=',
        0x0E => 0x08,
        0x0F => '\t',
        0x10 => 'q',
        0x11 => 'w',
        0x12 => 'e',
        0x13 => 'r',
        0x14 => 't',
        0x15 => 'y',
        0x16 => 'u',
        0x17 => 'i',
        0x18 => 'o',
        0x19 => 'p',
        0x1A => '[',
        0x1B => ']',
        0x1C => '\n',
        0x1E => 'a',
        0x1F => 's',
        0x20 => 'd',
        0x21 => 'f',
        0x22 => 'g',
        0x23 => 'h',
        0x24 => 'j',
        0x25 => 'k',
        0x26 => 'l',
        0x27 => ';',
        0x28 => '\'',
        0x29 => '`',
        0x2B => '\\',
        0x2C => 'z',
        0x2D => 'x',
        0x2E => 'c',
        0x2F => 'v',
        0x30 => 'b',
        0x31 => 'n',
        0x32 => 'm',
        0x33 => ',',
        0x34 => '.',
        0x35 => '/',
        0x39 => ' ',
        else => 0,
    };
}

test "translate set1 known and unknown" {
    try std.testing.expectEqual(@as(u8, 'a'), translateSet1(0x1E));
    try std.testing.expectEqual(@as(u8, '\n'), translateSet1(0x1C));
    try std.testing.expectEqual(@as(u8, 0), translateSet1(0x7F));
}

test "poll handles empty status, key release and regular key" {
    screens.init();
    arch.testReset();

    arch.testSetIn(STATUS_PORT, 0x00);
    try std.testing.expectEqual(@as(?KeyEvent, null), poll());

    arch.testSetIn(STATUS_PORT, 0x01);
    arch.testSetIn(DATA_PORT, 0x9E);
    const release = poll().?;
    try std.testing.expect(!release.pressed);

    arch.testSetIn(DATA_PORT, 0x1E);
    const key = poll().?;
    try std.testing.expect(key.pressed);
    try std.testing.expectEqual(@as(u8, 'a'), key.ascii);
}

test "poll handles screen switch keys" {
    screens.init();
    arch.testReset();

    arch.testSetIn(STATUS_PORT, 0x01);
    arch.testSetIn(DATA_PORT, 0x3C);
    _ = poll();
    try std.testing.expectEqual(@as(usize, 1), screens.activeScreen());

    arch.testSetIn(DATA_PORT, 0x3D);
    _ = poll();
    try std.testing.expectEqual(@as(usize, 2), screens.activeScreen());

    arch.testSetIn(DATA_PORT, 0x3B);
    _ = poll();
    try std.testing.expectEqual(@as(usize, 0), screens.activeScreen());
}
