const std = @import("std");

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
    std.debug.assert(len == 0 or @intFromPtr(dst) != 0);
    std.debug.assert(len == 0 or @intFromPtr(src) != 0);

    var i: usize = 0;
    while (i < len) : (i += 1) {
        dst[i] = src[i];
    }
}

pub fn memset(dst: [*]u8, value: u8, len: usize) void {
    std.debug.assert(len == 0 or @intFromPtr(dst) != 0);

    var i: usize = 0;
    while (i < len) : (i += 1) {
        dst[i] = value;
    }
}

test "strlen and strcmp" {
    const a: [*:0]const u8 = "abc";
    const b: [*:0]const u8 = "abc";
    const c: [*:0]const u8 = "abd";

    try std.testing.expectEqual(@as(usize, 3), strlen(a));
    try std.testing.expectEqual(@as(i32, 0), strcmp(a, b));
    try std.testing.expect(strcmp(a, c) < 0);
    try std.testing.expect(strcmp(c, a) > 0);
}

test "memcpy and memset" {
    var src = [_]u8{ 1, 2, 3, 4 };
    var dst = [_]u8{ 0, 0, 0, 0 };

    memcpy(&dst, &src, src.len);
    try std.testing.expectEqualSlices(u8, &src, &dst);

    memset(&dst, 0xAA, dst.len);
    try std.testing.expectEqual(@as(u8, 0xAA), dst[0]);
    try std.testing.expectEqual(@as(u8, 0xAA), dst[3]);

    memcpy(&dst, &src, 0);
    memset(&dst, 0x00, 0);
}
