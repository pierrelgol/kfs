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

GRUB_PC_DIR="/usr/lib/grub/i386-pc"
BOOT_IMG="$GRUB_PC_DIR/boot.img"

if [[ ! -f "$KERNEL_ELF" ]]; then
    echo "missing kernel: $KERNEL_ELF"
    exit 1
fi
if [[ ! -f "$BOOT_IMG" ]]; then
    echo "missing GRUB boot image: $BOOT_IMG"
    echo "install grub-pc-bin"
    exit 1
fi

rm -f "$IMG" "$ISO" "$CORE_IMG" "$BIOS_IMG"
rm -rf "$ISO_ROOT"
mkdir -p "$ISO_ROOT/boot/grub"

grub-mkstandalone \
    -d "$GRUB_PC_DIR" \
    -O i386-pc \
    -o "$CORE_IMG" \
    --install-modules="biosdisk multiboot normal configfile memdisk tar" \
    --modules="biosdisk multiboot normal configfile memdisk tar" \
    --locales="" --fonts="" --themes="" \
    "boot/grub/grub.cfg=$ROOT_DIR/grub/grub.cfg" \
    "boot/kernel.elf=$KERNEL_ELF"

cat "$BOOT_IMG" "$CORE_IMG" > "$IMG"
truncate -s 10M "$IMG"

grub-mkstandalone \
    -d "$GRUB_PC_DIR" \
    -O i386-pc-eltorito \
    -o "$BIOS_IMG" \
    --install-modules="biosdisk multiboot normal configfile memdisk tar" \
    --modules="biosdisk multiboot normal configfile memdisk tar" \
    --locales="" --fonts="" --themes="" \
    "boot/grub/grub.cfg=$ROOT_DIR/grub/grub.cfg" \
    "boot/kernel.elf=$KERNEL_ELF"

cp "$BIOS_IMG" "$ISO_ROOT/boot/grub/bios.img"
xorriso -as mkisofs -R \
    -b boot/grub/bios.img \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    -o "$ISO" "$ISO_ROOT" >/dev/null

echo "artifacts: $IMG $ISO"
