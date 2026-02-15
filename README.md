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
zig build run
zig build debug
zig build clean
zig build check-tools
```

## Makefile Wrapper

```sh
make
make test
make run
make debug
```

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
