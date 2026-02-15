# kfs

Kernel from Scratch implementation in Zig + NASM (i386, GRUB boot).

`build.zig` is the single source of truth for the build pipeline.
The `Makefile` exists only for 42 compliance and forwards to `zig build`.

## Zig Build Steps

```sh
zig build            # all: kernel + image + size checks
zig build kernel
zig build image
zig build size
zig build test
zig build coverage
zig build run
zig build run-selftest
zig build debug
zig build clean
zig build check-tools
```

## Makefile Wrapper

```sh
make
make test
make coverage
make run
make run-selftest
make debug
```

Runtime self-tests:
- Press `F12` in QEMU to run the in-kernel automated self-test suite.
- Press `Esc` while tests are active to cancel test mode cleanly.
- On first failure (without cancellation), the kernel panics immediately.

Coverage:
- `zig build coverage` (or `make coverage`) generates a kcov report at `build/coverage/index.html`.
- Coverage is optional and does not gate regular `zig build test`.

## Required tools

- `zig`
- `nasm`
- `ld` (binutils)
- `grub-mkstandalone` + `grub-pc-bin` (`/usr/lib/grub/i386-pc/boot.img`)
- `xorriso`
- `qemu-system-i386`

## Branches

- `kfs1`: kfs1 implementation
- `kfs2`: kfs2 implementation (based on `kfs1`)
