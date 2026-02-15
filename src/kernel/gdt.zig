const printk = @import("printk.zig");

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

fn gdtTable() *[ENTRY_COUNT]GdtEntry {
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
    gdt_flush(&gdtr, 0x10, 0x08);

    printk.printf("gdt loaded at %x\n", &[_]printk.PrintArg{.{ .u32 = @intCast(GDT_BASE) }});
}
