#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"

if [[ -f "$BUILD_DIR/kfs.img" ]]; then
    qemu-system-i386 -m 128M -drive file="$BUILD_DIR/kfs.img",format=raw,if=floppy
else
    qemu-system-i386 -m 128M -cdrom "$BUILD_DIR/kfs.iso"
fi
