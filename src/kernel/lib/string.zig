pub fn strlen(s: [*:0]const u8) usize {
    var len: usize = 0;
    while (s[len] != 0) : (len += 1) {}
    return len;
}

pub fn strcmp(a: [*:0]const u8, b: [*:0]const u8) i32 {
    var i: usize = 0;
    while (a[i] != 0 and b[i] != 0) : (i += 1) {
        if (a[i] != b[i]) {
            return @as(i32, a[i]) - @as(i32, b[i]);
        }
    }
    return @as(i32, a[i]) - @as(i32, b[i]);
}

pub fn memcpy(dst: [*]u8, src: [*]const u8, len: usize) void {
    var i: usize = 0;
    while (i < len) : (i += 1) {
        dst[i] = src[i];
    }
}

pub fn memset(dst: [*]u8, value: u8, len: usize) void {
    var i: usize = 0;
    while (i < len) : (i += 1) {
        dst[i] = value;
    }
}
