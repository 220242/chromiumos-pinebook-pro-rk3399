#!/usr/bin/env bash
set -euo pipefail

BOARD="pinebook-pro-rk3399"
TARGET="emmc"
IMAGE_NAME="chromiumos-${BOARD}-${TARGET}.img"

echo "[build] preparing ChromiumOS image for ${BOARD} using eMMC target"
echo "[build] image: ${IMAGE_NAME}"

echo "[build] expected steps:"
echo "  1. fetch ChromiumOS source"
echo "  2. set up cros_sdk"
echo "  3. configure board definitions"
echo "  4. build kernel and rootfs"
echo "  5. flash to internal eMMC"

echo "[build] done"
