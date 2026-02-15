const builtin = @import("builtin");
const std = @import("std");

const PORT_COUNT: usize = 65536;

var test_in_ports: [PORT_COUNT]u8 = [_]u8{0} ** PORT_COUNT;
var test_out_ports: [PORT_COUNT]u8 = [_]u8{0} ** PORT_COUNT;
var test_io_wait_count: usize = 0;

pub inline fn outb(port: u16, value: u8) void {
    if (builtin.is_test) {
        test_out_ports[port] = value;
        return;
    }

    asm volatile ("outb %[value], %[port]"
        :
        : [value] "{al}" (value), [port] "{dx}" (port)
    );
}

pub inline fn inb(port: u16) u8 {
    if (builtin.is_test) {
        return test_in_ports[port];
    }

    return asm volatile ("inb %[port], %[value]"
        : [value] "={al}" (-> u8)
        : [port] "{dx}" (port)
    );
}

pub inline fn ioWait() void {
    if (builtin.is_test) {
        test_io_wait_count += 1;
        return;
    }
    outb(0x80, 0);
}

pub fn haltForever() noreturn {
    while (true) {
        asm volatile ("hlt");
    }
}

pub fn testReset() void {
    std.debug.assert(builtin.is_test);
    @memset(&test_in_ports, 0);
    @memset(&test_out_ports, 0);
    test_io_wait_count = 0;
}

pub fn testSetIn(port: u16, value: u8) void {
    std.debug.assert(builtin.is_test);
    test_in_ports[port] = value;
}

pub fn testGetOut(port: u16) u8 {
    std.debug.assert(builtin.is_test);
    return test_out_ports[port];
}

pub fn testIoWaitCount() usize {
    std.debug.assert(builtin.is_test);
    return test_io_wait_count;
}

test "arch test mock in/out and io wait" {
    testReset();

    testSetIn(0x64, 0x11);
    try std.testing.expectEqual(@as(u8, 0x11), inb(0x64));

    outb(0x3D4, 0x0F);
    try std.testing.expectEqual(@as(u8, 0x0F), testGetOut(0x3D4));

    ioWait();
    try std.testing.expectEqual(@as(usize, 1), testIoWaitCount());
}
