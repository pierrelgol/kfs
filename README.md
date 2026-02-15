# kfs

Kernel from Scratch implementation in Zig + NASM (i386, GRUB boot).

## Build

```sh
make
```

## Test

```sh
make test
```

## Run

```sh
make run
```

## Required tools

- `zig`
- `nasm`
- `ld` (binutils)
- `grub-mkstandalone` + `grub-pc-bin`
- `xorriso`
- `qemu-system-i386`

## Branches

- `kfs1`: kfs1 implementation
- `kfs2`: kfs2 implementation (based on `kfs1`)
