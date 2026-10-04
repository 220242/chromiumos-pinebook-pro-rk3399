#!/usr/bin/env bash
set -euo pipefail

BOARD="pinebook-pro-rk3399"
TARGET="nvme"
IMAGE_NAME="chromiumos-${BOARD}-${TARGET}.img"

echo "[build] preparing ChromiumOS image for ${BOARD} using NVMe target"
echo "[build] image: ${IMAGE_NAME}"

echo "[build] expected steps:"
echo "  1. ensure PCIe/NVMe support is enabled in kernel"
echo "  2. build rootfs and board artifacts"
echo "  3. flash to NVMe media"
echo "  4. validate boot from root on NVMe"

echo "[build] done"
