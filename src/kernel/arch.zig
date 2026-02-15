pub inline fn outb(port: u16, value: u8) void {
    asm volatile ("outb %[value], %[port]"
        :
        : [value] "{al}" (value), [port] "{dx}" (port)
    );
}

pub inline fn inb(port: u16) u8 {
    return asm volatile ("inb %[port], %[value]"
        : [value] "={al}" (-> u8)
        : [port] "{dx}" (port)
    );
}

pub inline fn ioWait() void {
    outb(0x80, 0);
}

pub fn haltForever() noreturn {
    while (true) {
        asm volatile ("hlt");
    }
}
