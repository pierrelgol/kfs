const std = @import("std");

const arch = @import("arch.zig");
const gdt = @import("gdt.zig");
const keyboard = @import("keyboard.zig");
const printk = @import("printk.zig");
const screens = @import("screens.zig");
const selftest = @import("selftest.zig");
const shell = @import("shell.zig");

pub export fn kmain() callconv(.c) noreturn {
    screens.init();
    gdt.init();

    screens.setColor(0x0A);
    printk.println("42");

    screens.setColor(0x0F);
    printk.println("kfs2: gdt + stack + shell");
    printk.println("F1/F2/F3 switch screens, F12 starts selftests, Esc stops active tests");

    shell.init();
    shell.printPrompt();

    var ticks: u32 = 0;
    while (true) {
        if (keyboard.poll()) |event| {
            shell.handleKeyEvent(event);
        }

        selftest.tick();

        ticks +%= 1;
        if ((ticks & 0x3FFFFF) == 0) {
            arch.ioWait();
        }
    }
}

pub fn panic(_: []const u8, _: ?*anyopaque, _: ?usize) noreturn {
    screens.setColor(0x4F);
    printk.println("kernel panic");
    arch.haltForever();
}

test "shell handles char and function events" {
    screens.init();
    shell.init();
    shell.printPrompt();

    shell.handleKeyEvent(.{ .kind = .char, .pressed = true, .ascii = 'A', .function = null, .control = null, .scancode = 0x1E });
    try std.testing.expectEqual(@as(u16, 'A'), screens.testCell(5) & 0x00FF);

    shell.handleKeyEvent(.{ .kind = .function, .pressed = true, .ascii = 0, .function = .f2, .control = null, .scancode = 0x3C });
    try std.testing.expectEqual(@as(usize, 1), screens.activeScreen());
}

test "esc cancels active selftest mode" {
    screens.init();
    shell.init();
    selftest.start(.collect);
    try std.testing.expect(selftest.isActive());

    shell.handleKeyEvent(.{ .kind = .control, .pressed = true, .ascii = 0, .function = null, .control = .esc, .scancode = 0x01 });
    try std.testing.expect(!selftest.isActive());
}
