const builtin = @import("builtin");
const std = @import("std");

const keyboard = @import("keyboard.zig");
const printk = @import("printk.zig");
const screens = @import("screens.zig");
const strlib = @import("lib/string.zig");

pub const FailureMode = enum {
    panic_on_fail,
    collect,
};

pub const State = enum {
    idle,
    running,
    cancelled,
    done,
    failed,
};

pub const Summary = struct {
    total: usize,
    passed: usize,
    failed: usize,
};

const TestCase = struct {
    name: []const u8,
    func: *const fn () bool,
};

const runtime_tests = [_]TestCase{
    .{ .name = "string_stress", .func = testStringStress },
    .{ .name = "keyboard_decode_stress", .func = testKeyboardDecodeStress },
    .{ .name = "screen_stress", .func = testScreenStress },
    .{ .name = "printk_stress", .func = testPrintkStress },
};

var active_mode: FailureMode = .panic_on_fail;
var state: State = .idle;
var current_index: usize = 0;
var current_summary: Summary = .{ .total = 0, .passed = 0, .failed = 0 };

pub fn start(mode: FailureMode) void {
    if (state == .running) {
        return;
    }

    active_mode = mode;
    state = .running;
    current_index = 0;
    current_summary = .{ .total = runtime_tests.len, .passed = 0, .failed = 0 };
    printk.println("[selftest] start");
}

pub fn cancel() void {
    if (state != .running) {
        return;
    }
    state = .cancelled;
    printk.printlnf("[selftest] cancelled at index={d}", .{current_index});
}

pub fn isActive() bool {
    return state == .running;
}

pub fn getState() State {
    return state;
}

pub fn summary() Summary {
    return current_summary;
}

pub fn tick() void {
    if (state != .running) {
        return;
    }

    if (current_index >= runtime_tests.len) {
        state = .done;
        printk.printlnf("[selftest] done total={d} passed={d} failed={d}", .{ current_summary.total, current_summary.passed, current_summary.failed });
        return;
    }

    const test_case = runtime_tests[current_index];
    const ok = test_case.func();

    if (ok) {
        current_summary.passed += 1;
        printk.printlnf("[selftest] pass: {s}", .{test_case.name});
        current_index += 1;
        return;
    }

    current_summary.failed += 1;
    printk.printlnf("[selftest] fail: {s}", .{test_case.name});
    state = .failed;

    if (active_mode == .panic_on_fail and !builtin.is_test) {
        @panic("runtime selftest failed");
    }
}

pub fn runAll(mode: FailureMode) Summary {
    start(mode);
    while (isActive()) {
        tick();
        if (state == .failed and mode == .collect) {
            current_index += 1;
            if (current_index >= runtime_tests.len) {
                state = .done;
            } else {
                state = .running;
            }
        }
    }
    if (state == .done) {
        printk.printlnf("[selftest] done total={d} passed={d} failed={d}", .{ current_summary.total, current_summary.passed, current_summary.failed });
    }
    return summary();
}

fn testStringStress() bool {
    var src: [256]u8 = undefined;
    var dst: [256]u8 = undefined;

    var i: usize = 0;
    while (i < src.len) : (i += 1) {
        src[i] = @intCast(i & 0xFF);
        dst[i] = 0;
    }

    _ = strlib.memcpy(&dst, &src, src.len);

    i = 0;
    while (i < src.len) : (i += 1) {
        if (src[i] != dst[i]) {
            return false;
        }
    }

    _ = strlib.memset(&dst, 0x5A, dst.len);
    i = 0;
    while (i < dst.len) : (i += 1) {
        if (dst[i] != 0x5A) {
            return false;
        }
    }

    const a: [*:0]const u8 = "alpha";
    const b: [*:0]const u8 = "alpha";
    const c: [*:0]const u8 = "alpHb";

    return strlib.strlen(a) == 5 and strlib.strcmp(a, b) == 0 and strlib.strcmp(a, c) != 0;
}

fn testKeyboardDecodeStress() bool {
    const f1 = keyboard.decodeScancode(0x3B, false);
    if (f1.kind != .function or f1.function.? != .f1 or !f1.pressed) {
        return false;
    }

    const f12_release = keyboard.decodeScancode(0xD8, false);
    if (f12_release.kind != .function or f12_release.function.? != .f12 or f12_release.pressed) {
        return false;
    }

    const left = keyboard.decodeScancode(0x4B, true);
    if (left.kind != .control or left.control.? != .left) {
        return false;
    }

    var code: u8 = 0;
    while (code < 0x60) : (code +%= 1) {
        _ = keyboard.decodeScancode(code, false);
    }

    return true;
}

fn testScreenStress() bool {
    screens.clear();
    screens.setColor(0x1F);

    var i: usize = 0;
    while (i < (screens.WIDTH * screens.HEIGHT * 2)) : (i += 1) {
        screens.writeByte('A' + @as(u8, @intCast(i % 26)));
    }

    const cursor = screens.cursorPosition();
    if (cursor >= screens.WIDTH * screens.HEIGHT) {
        return false;
    }

    const cell0 = screens.peekCell(0);
    const ascii0: u8 = @truncate(cell0 & 0x00FF);
    return ascii0 >= 'A' and ascii0 <= 'Z';
}

fn testPrintkStress() bool {
    screens.clear();

    var i: usize = 0;
    while (i < 64) : (i += 1) {
        printk.printlnf("line={d} hex={x} ch={c}", .{ i, i * 17, 'a' + @as(u8, @intCast(i % 26)) });
    }

    const first = screens.peekCell(0);
    const first_ascii: u8 = @truncate(first & 0x00FF);
    return first_ascii != 0;
}

test "selftest start/tick/cancel lifecycle" {
    screens.init();

    start(.collect);
    try std.testing.expect(isActive());

    tick();
    try std.testing.expect(getState() == .running or getState() == .failed or getState() == .done);

    cancel();
    try std.testing.expectEqual(State.cancelled, getState());
}

test "runtime selftest summary collect mode" {
    screens.init();
    const result = runAll(.collect);
    try std.testing.expect(result.total >= 4);
    try std.testing.expectEqual(result.total, result.passed + result.failed);
}
