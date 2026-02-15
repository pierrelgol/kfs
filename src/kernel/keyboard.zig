const std = @import("std");

const arch = @import("arch.zig");

const DATA_PORT: u16 = 0x60;
const STATUS_PORT: u16 = 0x64;

pub const KeyKind = enum {
    char,
    function,
    control,
    unknown,
};

pub const FunctionKey = enum(u8) {
    f1 = 1,
    f2 = 2,
    f3 = 3,
    f4 = 4,
    f5 = 5,
    f6 = 6,
    f7 = 7,
    f8 = 8,
    f9 = 9,
    f10 = 10,
    f11 = 11,
    f12 = 12,
};

pub const ControlKey = enum {
    backspace,
    enter,
    tab,
    esc,
    left,
    right,
    home,
    end,
    delete,
};

pub const KeyEvent = struct {
    kind: KeyKind,
    pressed: bool,
    ascii: u8,
    function: ?FunctionKey,
    control: ?ControlKey,
    scancode: u8,
};

var pending_e0: bool = false;

pub fn poll() ?KeyEvent {
    if ((arch.inb(STATUS_PORT) & 0x01) == 0) {
        return null;
    }

    const raw_scancode = arch.inb(DATA_PORT);
    if (raw_scancode == 0xE0) {
        pending_e0 = true;
        return null;
    }

    const e0 = pending_e0;
    pending_e0 = false;
    return decodeScancode(raw_scancode, e0);
}

pub fn decodeScancode(raw_scancode: u8, e0_prefix: bool) KeyEvent {
    const pressed = (raw_scancode & 0x80) == 0;
    const scancode: u8 = raw_scancode & 0x7F;

    if (controlFromSet1(scancode, e0_prefix)) |control| {
        return .{
            .kind = .control,
            .pressed = pressed,
            .ascii = asciiForControl(control),
            .function = null,
            .control = control,
            .scancode = scancode,
        };
    }

    if (functionFromSet1(scancode, e0_prefix)) |function| {
        return .{
            .kind = .function,
            .pressed = pressed,
            .ascii = 0,
            .function = function,
            .control = null,
            .scancode = scancode,
        };
    }

    if (!e0_prefix) {
        const ascii = translateSet1(scancode);
        if (ascii != 0) {
            return .{
                .kind = .char,
                .pressed = pressed,
                .ascii = ascii,
                .function = null,
                .control = null,
                .scancode = scancode,
            };
        }
    }

    return .{
        .kind = .unknown,
        .pressed = pressed,
        .ascii = 0,
        .function = null,
        .control = null,
        .scancode = scancode,
    };
}

fn functionFromSet1(scancode: u8, e0_prefix: bool) ?FunctionKey {
    if (e0_prefix) return null;

    return switch (scancode) {
        0x3B => .f1,
        0x3C => .f2,
        0x3D => .f3,
        0x3E => .f4,
        0x3F => .f5,
        0x40 => .f6,
        0x41 => .f7,
        0x42 => .f8,
        0x43 => .f9,
        0x44 => .f10,
        0x57 => .f11,
        0x58 => .f12,
        else => null,
    };
}

fn controlFromSet1(scancode: u8, e0_prefix: bool) ?ControlKey {
    if (!e0_prefix) {
        return switch (scancode) {
            0x01 => .esc,
            0x0E => .backspace,
            0x0F => .tab,
            0x1C => .enter,
            else => null,
        };
    }

    return switch (scancode) {
        0x4B => .left,
        0x4D => .right,
        0x47 => .home,
        0x4F => .end,
        0x53 => .delete,
        else => null,
    };
}

fn asciiForControl(control: ControlKey) u8 {
    return switch (control) {
        .backspace => 0x08,
        .enter => '\n',
        .tab => '\t',
        else => 0,
    };
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

test "decode scancode function char and control" {
    const f12 = decodeScancode(0x58, false);
    try std.testing.expectEqual(KeyKind.function, f12.kind);
    try std.testing.expectEqual(FunctionKey.f12, f12.function.?);
    try std.testing.expect(f12.pressed);

    const f12_release = decodeScancode(0xD8, false);
    try std.testing.expectEqual(KeyKind.function, f12_release.kind);
    try std.testing.expect(!f12_release.pressed);

    const a = decodeScancode(0x1E, false);
    try std.testing.expectEqual(KeyKind.char, a.kind);
    try std.testing.expectEqual(@as(u8, 'a'), a.ascii);

    const esc = decodeScancode(0x01, false);
    try std.testing.expectEqual(KeyKind.control, esc.kind);
    try std.testing.expectEqual(ControlKey.esc, esc.control.?);

    const left = decodeScancode(0x4B, true);
    try std.testing.expectEqual(KeyKind.control, left.kind);
    try std.testing.expectEqual(ControlKey.left, left.control.?);
}

test "decode unknown and translation" {
    const unknown = decodeScancode(0x7F, false);
    try std.testing.expectEqual(KeyKind.unknown, unknown.kind);
    try std.testing.expectEqual(@as(u8, 0), unknown.ascii);

    try std.testing.expectEqual(@as(u8, 'a'), translateSet1(0x1E));
    try std.testing.expectEqual(@as(u8, 0), translateSet1(0x7F));
}

test "poll handles empty, regular and e0-prefixed keys" {
    arch.testReset();

    arch.testSetIn(STATUS_PORT, 0x00);
    try std.testing.expectEqual(@as(?KeyEvent, null), poll());

    arch.testSetIn(STATUS_PORT, 0x01);
    arch.testSetIn(DATA_PORT, 0x1E);
    const event = poll().?;
    try std.testing.expectEqual(KeyKind.char, event.kind);
    try std.testing.expectEqual(@as(u8, 'a'), event.ascii);

    arch.testSetIn(DATA_PORT, 0xE0);
    try std.testing.expectEqual(@as(?KeyEvent, null), poll());

    arch.testSetIn(DATA_PORT, 0x4B);
    const left = poll().?;
    try std.testing.expectEqual(KeyKind.control, left.kind);
    try std.testing.expectEqual(ControlKey.left, left.control.?);
}
