#!/usr/bin/env bash
set -euo pipefail

BOARD="pinebook-pro-rk3399"
TARGET="microsd"
IMAGE_NAME="chromiumos-${BOARD}-${TARGET}.img"

echo "[build] preparing ChromiumOS image for ${BOARD} using microSD target"
echo "[build] image: ${IMAGE_NAME}"

echo "[build] expected steps:"
echo "  1. prepare SD card"
echo "  2. build bootable ChromiumOS image"
echo "  3. flash to microSD"
echo "  4. validate kernel and storage detection"

echo "[build] done"
