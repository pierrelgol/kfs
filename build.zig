const std = @import("std");

const max_size_bytes = 10 * 1024 * 1024;

pub fn build(b: *std.Build) void {
    const build_dir = "build";
    const kernel_elf = b.pathJoin(&.{ build_dir, "kernel.elf" });
    const kernel_obj = b.pathJoin(&.{ build_dir, "kernel.o" });
    const boot_obj = b.pathJoin(&.{ build_dir, "boot.o" });
    const core_img = b.pathJoin(&.{ build_dir, "core.img" });
    const bios_img = b.pathJoin(&.{ build_dir, "bios.img" });
    const raw_img = b.pathJoin(&.{ build_dir, "kfs.img" });
    const iso_img = b.pathJoin(&.{ build_dir, "kfs.iso" });
    const iso_root = b.pathJoin(&.{ build_dir, "isofiles" });
    const iso_grub_dir = b.pathJoin(&.{ build_dir, "isofiles", "boot", "grub" });

    const check_kernel_tools = addToolChecks(b, &.{ "zig", "nasm", "ld" });
    const check_image_tools = addToolChecks(b, &.{ "grub-mkstandalone", "xorriso" });
    const check_qemu = addToolChecks(b, &.{ "qemu-system-i386" });
    const check_kcov = addToolChecks(b, &.{ "kcov" });
    const check_boot_img = b.addSystemCommand(&.{ "test", "-f", "/usr/lib/grub/i386-pc/boot.img" });

    const check_tools_step = b.step("check-tools", "Check required external tools and GRUB BIOS image");
    check_tools_step.dependOn(check_kernel_tools);
    check_tools_step.dependOn(check_image_tools);
    check_tools_step.dependOn(check_qemu);
    check_tools_step.dependOn(check_kcov);
    check_tools_step.dependOn(&check_boot_img.step);

    const assemble_boot = b.addSystemCommand(&.{
        "sh", "-c", b.fmt("mkdir -p {s} && nasm -f elf32 src/boot/boot.asm -o {s}", .{ build_dir, boot_obj }),
    });
    assemble_boot.step.dependOn(check_kernel_tools);

    const compile_kernel = b.addSystemCommand(&.{
        "sh", "-c", b.fmt(
            "mkdir -p {s} && zig build-obj src/kernel/main.zig -target x86-freestanding-none -mcpu i386 -O ReleaseSmall -fstrip -fno-stack-check -fno-stack-protector -femit-bin={s}",
            .{ build_dir, kernel_obj },
        ),
    });
    compile_kernel.step.dependOn(check_kernel_tools);

    const link_kernel = b.addSystemCommand(&.{
        "ld", "-m", "elf_i386", "-nostdlib", "-T", "linker/kernel.ld",
        "-o", kernel_elf, boot_obj, kernel_obj,
    });
    link_kernel.step.dependOn(&assemble_boot.step);
    link_kernel.step.dependOn(&compile_kernel.step);

    const kernel_step = b.step("kernel", "Build kernel ELF");
    kernel_step.dependOn(&link_kernel.step);

    const clean_image_artifacts = b.addSystemCommand(&.{
        "sh", "-c", b.fmt("rm -f {s} {s} {s} {s} && rm -rf {s}", .{ raw_img, iso_img, core_img, bios_img, iso_root }),
    });
    clean_image_artifacts.step.dependOn(&link_kernel.step);

    const make_iso_dir = b.addSystemCommand(&.{ "mkdir", "-p", iso_grub_dir });
    make_iso_dir.step.dependOn(&clean_image_artifacts.step);

    const build_core_img = b.addSystemCommand(&.{
        "grub-mkstandalone",
        "-d", "/usr/lib/grub/i386-pc",
        "-O", "i386-pc",
        "-o", core_img,
        "--install-modules=biosdisk multiboot normal configfile memdisk tar",
        "--modules=biosdisk multiboot normal configfile memdisk tar",
        "--locales=",
        "--fonts=",
        "--themes=",
        "boot/grub/grub.cfg=grub/grub.cfg",
        b.fmt("boot/kernel.elf={s}", .{kernel_elf}),
    });
    build_core_img.step.dependOn(check_image_tools);
    build_core_img.step.dependOn(&check_boot_img.step);
    build_core_img.step.dependOn(&make_iso_dir.step);

    const build_raw_img = b.addSystemCommand(&.{
        "sh", "-c", b.fmt("cat /usr/lib/grub/i386-pc/boot.img {s} > {s}", .{ core_img, raw_img }),
    });
    build_raw_img.step.dependOn(&build_core_img.step);

    const truncate_raw_img = b.addSystemCommand(&.{ "truncate", "-s", "10M", raw_img });
    truncate_raw_img.step.dependOn(&build_raw_img.step);

    const build_bios_img = b.addSystemCommand(&.{
        "grub-mkstandalone",
        "-d", "/usr/lib/grub/i386-pc",
        "-O", "i386-pc-eltorito",
        "-o", bios_img,
        "--install-modules=biosdisk multiboot normal configfile memdisk tar",
        "--modules=biosdisk multiboot normal configfile memdisk tar",
        "--locales=",
        "--fonts=",
        "--themes=",
        "boot/grub/grub.cfg=grub/grub.cfg",
        b.fmt("boot/kernel.elf={s}", .{kernel_elf}),
    });
    build_bios_img.step.dependOn(check_image_tools);
    build_bios_img.step.dependOn(&check_boot_img.step);
    build_bios_img.step.dependOn(&make_iso_dir.step);

    const copy_bios_for_iso = b.addSystemCommand(&.{ "cp", bios_img, b.pathJoin(&.{ iso_grub_dir, "bios.img" }) });
    copy_bios_for_iso.step.dependOn(&build_bios_img.step);

    const build_iso = b.addSystemCommand(&.{
        "xorriso", "-as", "mkisofs", "-R",
        "-b", "boot/grub/bios.img",
        "-no-emul-boot", "-boot-load-size", "4", "-boot-info-table",
        "-o", iso_img,
        iso_root,
    });
    build_iso.step.dependOn(&copy_bios_for_iso.step);

    const image_step = b.step("image", "Build GRUB raw image and ISO");
    image_step.dependOn(&truncate_raw_img.step);
    image_step.dependOn(&build_iso.step);

    const size_kernel = b.addSystemCommand(&.{
        "sh", "-c", b.fmt("test ! -f {s} || [ $(stat -c %s {s}) -le {d} ]", .{ kernel_elf, kernel_elf, max_size_bytes }),
    });
    size_kernel.step.dependOn(&link_kernel.step);

    const size_raw = b.addSystemCommand(&.{
        "sh", "-c", b.fmt("test ! -f {s} || [ $(stat -c %s {s}) -le {d} ]", .{ raw_img, raw_img, max_size_bytes }),
    });
    size_raw.step.dependOn(&truncate_raw_img.step);

    const size_iso = b.addSystemCommand(&.{
        "sh", "-c", b.fmt("test ! -f {s} || [ $(stat -c %s {s}) -le {d} ]", .{ iso_img, iso_img, max_size_bytes }),
    });
    size_iso.step.dependOn(&build_iso.step);

    const size_step = b.step("size", "Validate size constraints <= 10 MiB");
    size_step.dependOn(&size_kernel.step);
    size_step.dependOn(&size_raw.step);
    size_step.dependOn(&size_iso.step);

    const test_cmd = b.addSystemCommand(&.{ "zig", "test", "src/kernel/tests.zig", "-O", "Debug" });
    test_cmd.step.dependOn(check_kernel_tools);
    const test_step = b.step("test", "Run kernel unit tests");
    test_step.dependOn(&test_cmd.step);

    const coverage_cmd = b.addSystemCommand(&.{ "sh", "-c", "mkdir -p build && rm -rf build/coverage build/tests_coverage && zig test src/kernel/tests.zig -O Debug --test-no-exec -femit-bin=build/tests_coverage && kcov --clean --include-path=$(pwd)/src/kernel build/coverage build/tests_coverage" });
    coverage_cmd.step.dependOn(check_kernel_tools);
    coverage_cmd.step.dependOn(check_kcov);
    const coverage_step = b.step("coverage", "Generate kcov coverage report for host kernel tests");
    coverage_step.dependOn(&coverage_cmd.step);

    const run_cmd = b.addSystemCommand(&.{
        "qemu-system-i386", "-m", "128M", "-drive", b.fmt("file={s},format=raw,if=floppy", .{raw_img}),
    });
    run_cmd.step.dependOn(check_qemu);
    run_cmd.step.dependOn(&truncate_raw_img.step);
    const run_step = b.step("run", "Run kernel image in QEMU");
    run_step.dependOn(&run_cmd.step);

    const selftest_hint = b.addSystemCommand(&.{ "sh", "-c", "echo \"Press F12 in QEMU to run runtime selftests.\"" });
    selftest_hint.step.dependOn(&truncate_raw_img.step);

    const run_selftest_cmd = b.addSystemCommand(&.{
        "qemu-system-i386", "-m", "128M", "-drive", b.fmt("file={s},format=raw,if=floppy", .{raw_img}),
    });
    run_selftest_cmd.step.dependOn(check_qemu);
    run_selftest_cmd.step.dependOn(&selftest_hint.step);
    const run_selftest_step = b.step("run-selftest", "Run kernel and trigger runtime selftests with F12");
    run_selftest_step.dependOn(&run_selftest_cmd.step);

    const debug_cmd = b.addSystemCommand(&.{
        "qemu-system-i386", "-m", "128M", "-s", "-S", "-drive", b.fmt("file={s},format=raw,if=floppy", .{raw_img}),
    });
    debug_cmd.step.dependOn(check_qemu);
    debug_cmd.step.dependOn(&truncate_raw_img.step);
    const debug_step = b.step("debug", "Run kernel image in QEMU with gdb stub");
    debug_step.dependOn(&debug_cmd.step);

    const clean_cmd = b.addSystemCommand(&.{ "sh", "-c", "rm -rf build" });
    const clean_step = b.step("clean", "Remove build artifacts");
    clean_step.dependOn(&clean_cmd.step);

    const all_step = b.step("all", "Build kernel, images, and validate size");
    all_step.dependOn(size_step);
    b.default_step = all_step;
}

fn addToolChecks(b: *std.Build, tools: []const []const u8) *std.Build.Step {
    const group = b.step(b.fmt("check-{s}", .{tools[0]}), "Check tool availability");
    for (tools) |tool| {
        const check = b.addSystemCommand(&.{ "sh", "-c", b.fmt("command -v {s} >/dev/null", .{tool}) });
        group.dependOn(&check.step);
    }
    return group;
}
