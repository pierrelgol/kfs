const builtin = @import("builtin");
const printk = @import("printk.zig");

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
