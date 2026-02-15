const builtin = @import("builtin");
const std = @import("std");
const printk = @import("printk.zig");
const screens = @import("screens.zig");

extern fn read_esp() callconv(.c) u32;
extern fn read_ebp() callconv(.c) u32;

pub fn dumpKernelStack() void {
    const esp = readEsp();
    const ebp = readEbp();

    printk.printf("stack esp=%x ebp=%x\n", &[_]printk.PrintArg{
        .{ .u32 = esp },
        .{ .u32 = ebp },
    });

    dumpRawWords(esp);
    dumpFrames(ebp);
}

fn readEsp() u32 {
    if (builtin.is_test) {
        return 0;
    }
    return read_esp();
}

fn readEbp() u32 {
    if (builtin.is_test) {
        return 0;
    }
    return read_ebp();
}

fn dumpRawWords(esp: u32) void {
    printk.println("raw stack words:");

    if (builtin.is_test) {
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            const addr = 0x1000 + @as(u32, @intCast(i * 4));
            const value = 0xA000_0000 + @as(u32, @intCast(i));
            printk.printf("  [%x] = %x\n", &[_]printk.PrintArg{
                .{ .u32 = addr },
                .{ .u32 = value },
            });
        }
        return;
    }

    const ptr = @as([*]const u32, @ptrFromInt(esp));
    var i: usize = 0;
    while (i < 12) : (i += 1) {
        const addr = esp + @as(u32, @intCast(i * 4));
        const value = ptr[i];
        printk.printf("  [%x] = %x\n", &[_]printk.PrintArg{
            .{ .u32 = addr },
            .{ .u32 = value },
        });
    }
}

fn dumpFrames(ebp_start: u32) void {
    printk.println("frame chain:");

    if (builtin.is_test) {
        var depth: usize = 0;
        while (depth < 2) : (depth += 1) {
            const ebp = 0x2000 + @as(u32, @intCast(depth * 0x20));
            const ret = 0x3000 + @as(u32, @intCast(depth * 0x10));
            const next = if (depth == 0) ebp + 0x20 else 0;
            printk.printf("  #%u ebp=%x ret=%x next=%x\n", &[_]printk.PrintArg{
                .{ .u32 = @intCast(depth) },
                .{ .u32 = ebp },
                .{ .u32 = ret },
                .{ .u32 = next },
            });
        }
        return;
    }

    var frame_ptr = ebp_start;
    var depth: usize = 0;

    while (frame_ptr != 0 and depth < 8) : (depth += 1) {
        const frame = @as(*const [2]u32, @ptrFromInt(frame_ptr));
        const next = frame[0];
        const ret = frame[1];

        printk.printf("  #%u ebp=%x ret=%x next=%x\n", &[_]printk.PrintArg{
            .{ .u32 = @intCast(depth) },
            .{ .u32 = frame_ptr },
            .{ .u32 = ret },
            .{ .u32 = next },
        });

        if (next <= frame_ptr) {
            break;
        }
        frame_ptr = next;
    }
}

test "dump kernel stack prints summary in test mode" {
    screens.init();
    dumpKernelStack();

    try std.testing.expectEqual(@as(u16, 's'), screens.testCell(0) & 0x00FF);
    try std.testing.expect(screens.cursorPosition() > 0);
}
