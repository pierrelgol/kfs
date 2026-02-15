const builtin = @import("builtin");
const std = @import("std");
const printk = @import("printk.zig");
const screens = @import("screens.zig");

const GDT_BASE: usize = 0x00000800;
const ENTRY_COUNT: usize = 7;

const GdtEntry = packed struct {
    limit_low: u16,
    base_low: u16,
    base_middle: u8,
    access: u8,
    granularity: u8,
    base_high: u8,
};

const GdtPointer = packed struct {
    limit: u16,
    base: u32,
};

extern fn gdt_flush(gdtr: *const GdtPointer, data_selector: u16, code_selector: u16) callconv(.c) void;

var gdtr: GdtPointer = .{ .limit = 0, .base = 0 };
var test_gdt_table: [ENTRY_COUNT]GdtEntry = undefined;

fn gdtTable() *[ENTRY_COUNT]GdtEntry {
    if (builtin.is_test) {
        return &test_gdt_table;
    }
    return @as(*[ENTRY_COUNT]GdtEntry, @ptrFromInt(GDT_BASE));
}

fn entry(base: u32, limit: u32, access: u8, granularity_flags: u8) GdtEntry {
    return .{
        .limit_low = @truncate(limit & 0xFFFF),
        .base_low = @truncate(base & 0xFFFF),
        .base_middle = @truncate((base >> 16) & 0xFF),
        .access = access,
        .granularity = @truncate(((limit >> 16) & 0x0F) | (granularity_flags & 0xF0)),
        .base_high = @truncate((base >> 24) & 0xFF),
    };
}

pub fn init() void {
    const table = gdtTable();

    table[0] = entry(0, 0, 0, 0); // null
    table[1] = entry(0, 0xFFFFF, 0x9A, 0xCF); // kernel code
    table[2] = entry(0, 0xFFFFF, 0x92, 0xCF); // kernel data
    table[3] = entry(0, 0xFFFFF, 0x92, 0xCF); // kernel stack
    table[4] = entry(0, 0xFFFFF, 0xFA, 0xCF); // user code
    table[5] = entry(0, 0xFFFFF, 0xF2, 0xCF); // user data
    table[6] = entry(0, 0xFFFFF, 0xF2, 0xCF); // user stack

    gdtr.limit = @sizeOf([ENTRY_COUNT]GdtEntry) - 1;
    gdtr.base = GDT_BASE;

    // 0x10 = kernel data selector (index 2), 0x08 = kernel code selector (index 1)
    gdtFlush(&gdtr, 0x10, 0x08);

    printk.printf("gdt loaded at %x\n", &[_]printk.PrintArg{.{ .u32 = @intCast(GDT_BASE) }});
}

fn gdtFlush(gdtr_ptr: *const GdtPointer, data_selector: u16, code_selector: u16) void {
    if (builtin.is_test) {
        return;
    }
    gdt_flush(gdtr_ptr, data_selector, code_selector);
}

test "gdt init populates required entries and gdtr" {
    screens.init();
    init();
    const table = gdtTable();

    try std.testing.expectEqual(@as(u8, 0), table[0].access);
    try std.testing.expectEqual(@as(u8, 0x9A), table[1].access); // kernel code
    try std.testing.expectEqual(@as(u8, 0x92), table[2].access); // kernel data
    try std.testing.expectEqual(@as(u8, 0x92), table[3].access); // kernel stack
    try std.testing.expectEqual(@as(u8, 0xFA), table[4].access); // user code
    try std.testing.expectEqual(@as(u8, 0xF2), table[5].access); // user data
    try std.testing.expectEqual(@as(u8, 0xF2), table[6].access); // user stack

    try std.testing.expectEqual(@as(u16, @sizeOf([ENTRY_COUNT]GdtEntry) - 1), gdtr.limit);
    try std.testing.expectEqual(@as(u32, GDT_BASE), gdtr.base);
}
