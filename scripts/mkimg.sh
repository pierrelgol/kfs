#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
KERNEL_ELF="$BUILD_DIR/kernel.elf"
IMG="$BUILD_DIR/kfs.img"
ISO="$BUILD_DIR/kfs.iso"
CORE_IMG="$BUILD_DIR/core.img"
BIOS_IMG="$BUILD_DIR/bios.img"
ISO_ROOT="$BUILD_DIR/isofiles"

if [[ ! -f "$KERNEL_ELF" ]]; then
    echo "missing kernel: $KERNEL_ELF"
    exit 1
fi

mkdir -p "$BUILD_DIR"
rm -f "$IMG" "$ISO" "$CORE_IMG" "$BIOS_IMG"
rm -rf "$ISO_ROOT"

GRUB_PC_DIR="/usr/lib/grub/i386-pc"
BOOT_IMG="$GRUB_PC_DIR/boot.img"
if [[ ! -f "$BOOT_IMG" ]]; then
    TOOLCHAIN_DIR="$BUILD_DIR/toolchain"
    mkdir -p "$TOOLCHAIN_DIR"
    if ! ls "$TOOLCHAIN_DIR"/grub-pc-bin_*_amd64.deb >/dev/null 2>&1; then
        (
            cd "$TOOLCHAIN_DIR"
            apt download grub-pc-bin >/dev/null
        )
    fi
    if [[ ! -d "$TOOLCHAIN_DIR/grub-pc-bin" ]]; then
        dpkg-deb -x "$TOOLCHAIN_DIR"/grub-pc-bin_*_amd64.deb "$TOOLCHAIN_DIR/grub-pc-bin"
    fi
    GRUB_PC_DIR="$TOOLCHAIN_DIR/grub-pc-bin/usr/lib/grub/i386-pc"
    BOOT_IMG="$GRUB_PC_DIR/boot.img"
    if [[ ! -f "$BOOT_IMG" ]]; then
        echo "missing GRUB boot image after local bootstrap: $BOOT_IMG"
        exit 1
    fi
fi

# Raw image with GRUB stage1 + embedded core image and embedded kernel file.
grub-mkstandalone \
    -d "$GRUB_PC_DIR" \
    -O i386-pc \
    -o "$CORE_IMG" \
    --install-modules="biosdisk multiboot normal configfile memdisk tar" \
    --modules="biosdisk multiboot normal configfile memdisk tar" \
    --locales="" \
    --fonts="" \
    --themes="" \
    "boot/grub/grub.cfg=$ROOT_DIR/grub/grub.cfg" \
    "boot/kernel.elf=$KERNEL_ELF"

cat "$BOOT_IMG" "$CORE_IMG" > "$IMG"
truncate -s 10M "$IMG"

# ISO fallback artifact for easier optical-boot testing.
grub-mkstandalone \
    -d "$GRUB_PC_DIR" \
    -O i386-pc-eltorito \
    -o "$BIOS_IMG" \
    --install-modules="biosdisk multiboot normal configfile memdisk tar" \
    --modules="biosdisk multiboot normal configfile memdisk tar" \
    --locales="" \
    --fonts="" \
    --themes="" \
    "boot/grub/grub.cfg=$ROOT_DIR/grub/grub.cfg" \
    "boot/kernel.elf=$KERNEL_ELF"

mkdir -p "$ISO_ROOT/boot/grub"
cp "$BIOS_IMG" "$ISO_ROOT/boot/grub/bios.img"
xorriso -as mkisofs -R \
    -b boot/grub/bios.img \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    -o "$ISO" "$ISO_ROOT" >/dev/null

echo "artifacts: $IMG $ISO"
