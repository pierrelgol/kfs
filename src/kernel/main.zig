const std = @import("std");

const arch = @import("arch.zig");
const keyboard = @import("keyboard.zig");
const printk = @import("printk.zig");
const screens = @import("screens.zig");

pub export fn kmain() callconv(.c) noreturn {
    screens.init();
    screens.setColor(0x0A);
    printk.println("42");

    screens.setColor(0x0F);
    printk.println("kfs1: Zig + asm kernel");
    printk.println("F1/F2/F3 switch screens, type to echo");

    var ticks: u32 = 0;
    while (true) {
        if (keyboard.poll()) |event| {
            processKeyEvent(event);
        }

        ticks +%= 1;
        if ((ticks & 0x3FFFFF) == 0) {
            arch.ioWait();
        }
    }
}

fn processKeyEvent(event: keyboard.KeyEvent) void {
    if (!event.pressed) {
        return;
    }
    if (event.ascii == 0) {
        return;
    }

    if (event.ascii == 0x08) {
        screens.backspace();
        return;
    }

    std.debug.assert(event.ascii >= 0x09 or event.ascii == '\n');
    screens.writeByte(event.ascii);
}

pub fn panic(_: []const u8, _: ?*anyopaque, _: ?usize) noreturn {
    screens.setColor(0x4F);
    printk.println("kernel panic");
    arch.haltForever();
}

test "process key events" {
    screens.init();

    processKeyEvent(.{ .ascii = 'A', .pressed = true });
    try std.testing.expectEqual(@as(u16, 'A'), screens.testCell(0) & 0x00FF);

    processKeyEvent(.{ .ascii = 0x08, .pressed = true });
    try std.testing.expectEqual(@as(usize, 0), screens.cursorPosition());

    processKeyEvent(.{ .ascii = 'B', .pressed = false });
    try std.testing.expectEqual(@as(usize, 0), screens.cursorPosition());

    processKeyEvent(.{ .ascii = 0, .pressed = true });
    try std.testing.expectEqual(@as(usize, 0), screens.cursorPosition());
}
