const arch = @import("arch.zig");
const screens = @import("screens.zig");
const printk = @import("printk.zig");
const keyboard = @import("keyboard.zig");

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
            if (!event.pressed) {
                continue;
            }
            if (event.ascii == 0) {
                continue;
            }
            if (event.ascii == 0x08) {
                screens.backspace();
                continue;
            }
            screens.writeByte(event.ascii);
        }

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
