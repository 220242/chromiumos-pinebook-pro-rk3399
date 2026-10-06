# Upstream sources and references

This file keeps the list of upstream and board-specific sources that are relevant to the PineBook Pro RK3399 ChromiumOS port.

## Official ChromiumOS sources

- ChromiumOS docs: https://chromium.googlesource.com/chromiumos/docs/
- ChromiumOS manifest: https://chromium.googlesource.com/chromiumos/manifest
- ChromiumOS build scripts: https://chromium.googlesource.com/chromiumos/platform/crosutils/
- ChromiumOS kernel sources: https://chromium.googlesource.com/chromiumos/third_party/kernel/
- ChromiumOS U-Boot: https://chromium.googlesource.com/chromiumos/third_party/u-boot/
- ChromiumOS ARM trusted firmware: https://chromium.googlesource.com/chromiumos/third_party/arm-trusted-firmware/

## PineBook Pro and RK3399 sources

- Pine64 Wiki: https://wiki.pine64.org/wiki/PineBook_Pro
- Pine64 Linux kernel: https://github.com/pine64/linux
- Pine64 U-Boot: https://github.com/pine64/u-boot
- Armbian PineBook Pro: https://www.armbian.com/pinebook-pro/
- Armbian build system: https://github.com/armbian/build
- Rockchip Linux repositories: https://github.com/rockchip-linux
- Rockchip RK3399 firmware: https://github.com/rockchip-linux/rkbin
- Rockchip Linux SDK: https://github.com/rockchip-linux/rockchip-linux-sdk
- Linux kernel mainline: https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/

## Driver and hardware support references

- Rockchip DRM / display: https://github.com/torvalds/linux/tree/master/drivers/gpu/drm/rockchip
- Mali GPU support: https://github.com/rockchip-linux/gpu-mali-midgard
- Rockchip audio stack: https://github.com/rockchip-linux/linux/tree/release/sound/soc/rockchip
- PineBook Pro device tree (upstream Linux): https://github.com/torvalds/linux/blob/master/arch/arm64/boot/dts/rockchip/rk3399-pinebook-pro.dts
- Broadcom brcmfmac Wi-Fi driver (AP6256 / BCM43456): https://github.com/torvalds/linux/tree/master/drivers/net/wireless/broadcom/brcm80211/brcmfmac
- Broadcom UART Bluetooth driver (hci_bcm, BCM4345C5): https://github.com/torvalds/linux/blob/master/drivers/bluetooth/hci_bcm.c
- Broadcom firmware (linux-firmware): https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/tree/brcm

## General notes

Use these sources as references, not as a direct upstream replacement. A ChromiumOS port still needs the proper ChromeOS build environment, board definitions, and hardware-specific policy decisions.
