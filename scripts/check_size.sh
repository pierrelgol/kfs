#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"

limit=$((10 * 1024 * 1024))
for artifact in "$BUILD_DIR/kernel.elf" "$BUILD_DIR/kfs.img" "$BUILD_DIR/kfs.iso"; do
    if [[ -f "$artifact" ]]; then
        size=$(stat -c %s "$artifact")
        if (( size > limit )); then
            echo "artifact too large: $artifact ($size bytes)"
            exit 1
        fi
    fi
done

echo "size check passed"
