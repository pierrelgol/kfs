#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"

qemu-system-i386 -m 128M -drive file="$BUILD_DIR/kfs.img",format=raw,if=floppy
