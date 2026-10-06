# ChromiumOS for PineBook Pro (RK3399)

This repository is a starter workspace for building and customizing ChromiumOS for the PineBook Pro board using the Rockchip RK3399 SoC.

It is intentionally structured as a development scaffold, not as a complete upstream ChromiumOS checkout. The goal is to provide a clean starting point for:

- board metadata and architecture notes
- build instructions for a custom `chromiumos` environment
- kernel and device-specific configuration templates
- overlays, scripts, and debugging notes for PineBook Pro
- support for multiple storage backends (NVMe, eMMC, microSD)

## Device target

- Model: PineBook Pro
- SoC: Rockchip RK3399
- Platform notes: ARM64, multi-core A53/A72, eMMC/SD, USB, audio, Wi-Fi/Bluetooth, display, keyboard/touchpad
- Storage: internal eMMC, microSD card, optional NVMe via adapter
- Use case: ChromiumOS porting / custom board development

## Storage support

This port targets three primary storage options:

### 1. eMMC (internal storage)
- Default boot media on most PineBook Pro units
- Higher performance and reliability
- Internal storage partition scheme

### 2. microSD card
- Removable external storage
- Fallback or experimental boot option
- Variable performance depending on card quality

### 3. NVMe (M.2 SSD via adapter or native slot)
- Optional high-performance upgrade
- Requires compatible M.2 to USB adapter or direct connector
- Best performance characteristics

One image is built (see `build/README.md`); it boots from microSD and can then be installed to eMMC or NVMe.

## Repository layout

```text
.
├── README.md
├── .gitattributes             keeps shell scripts LF on Windows clones
├── boards/
│   └── pinebook-pro-rk3399/
│       ├── board.conf         BOARD_NAME used by the build scripts
│       ├── overlays/          device tree fragments (emmc, microsd, nvme)
│       └── kernel-config/     kernel config fragments
├── build/
│   ├── README.md              how the build scripts work
│   ├── linux/                 preflight, sync, build, flash-microsd
│   └── windows/               Start-PinebookBuild.ps1 (runs the Linux scripts in WSL2)
├── docs/                      hardware, porting, storage and Windows build notes
└── sources/
    └── UPSTREAM_SOURCES.md
```

## Upstream ChromiumOS sources

### Official ChromiumOS repositories

- Main ChromiumOS source tree (all repositories): https://chromium.googlesource.com/chromiumos/ (fetched with `repo` from the manifest below)
- ChromiumOS developer guide: https://www.chromium.org/chromium-os/developer-library/guides/development/developer-guide/
- ChromiumOS build scripts: https://chromium.googlesource.com/chromiumos/platform/crosutils/
- ChromiumOS manifest: https://chromium.googlesource.com/chromiumos/manifest
- ChromiumOS docs: https://chromium.googlesource.com/chromiumos/docs/
- Latest release branch: `main` or check `https://chromium.googlesource.com/chromiumos/manifest/+refs` for active branches

### Key kernel and bootloader sources

- ChromiumOS Linux kernel: https://chromium.googlesource.com/chromiumos/third_party/kernel/
- U-Boot: https://chromium.googlesource.com/chromiumos/third_party/u-boot/
- ARM trusted firmware: https://chromium.googlesource.com/chromiumos/third_party/arm-trusted-firmware/

## PineBook Pro-specific sources

### Linux kernel support

- Armbian PineBook Pro kernel: https://github.com/armbian/build
  - Good reference for PineBook Pro patches and device trees
  - RK3399 driver configurations
  - Audio, display, and touchpad fixes

- Pine64 official kernel repository: https://github.com/pine64/linux
  - PineBook Pro mainline patches
  - Device tree definitions
  - Hardware-specific tweaks

- Mainline Linux RK3399 support: https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/
  - Search for `rk3399` in device trees
  - Standard ARM64 and RK3399 SoC drivers

### Bootloader (U-Boot)

- Pine64 U-Boot fork: https://github.com/pine64/u-boot
  - PineBook Pro boot sequence configurations
  - eMMC, SD card, and USB boot support
  - RK3399-specific U-Boot patches

- Upstream U-Boot with RK3399: https://source.denx.de/u-boot/u-boot/
  - Standard Rockchip RK3399 support
  - Generic ARM64 bootloader code

### Firmware and binary blobs

- Rockchip RKBIN: https://github.com/rockchip-linux/rkbin
  - RK3399 DDR initialization firmware
  - Mini-loader binaries

- Rockchip Linux SDK reference: https://github.com/rockchip-linux/rockchip-linux-sdk
  - Full RK3399 Linux porting reference
  - Display, audio, and graphics drivers

### Display, panel, and GPU drivers

- Rockchip Mali GPU drivers: https://github.com/rockchip-linux/gpu-mali-midgard
  - Mali T860 GPU support for RK3399
  - Display composition and rendering

- DRM/KMS display support: https://github.com/torvalds/linux/tree/master/drivers/gpu/drm/rockchip
  - PineBook Pro panel initialization
  - HDMI and USB-C display output support

### Audio support

- Rockchip audio driver package: https://github.com/rockchip-linux/linux/tree/release/sound/soc/rockchip
  - Internal speaker and headphone support
  - Codec: Everest Semi ES8316 on I2S1 (`CONFIG_SND_SOC_ES8316`)

### Wi-Fi and Bluetooth

- Module: AMPAK AP6256 (Broadcom BCM43456 Wi-Fi on SDIO, BCM4345C5 Bluetooth on UART)
- Wi-Fi driver (brcmfmac): https://github.com/torvalds/linux/tree/master/drivers/net/wireless/broadcom/brcm80211/brcmfmac
- Bluetooth driver (hci_bcm): https://github.com/torvalds/linux/blob/master/drivers/bluetooth/hci_bcm.c
- Firmware: https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/tree/brcm

### Keyboard and touchpad

- PineBook Pro hardware notes and community docs: https://wiki.pine64.org/wiki/PineBook_Pro
  - Hardware specifications and revision history
  - Community fixes and keyboard/touchpad notes

### Testing and debugging

- PineBook Pro wiki and community docs: https://wiki.pine64.org/wiki/PineBook_Pro
  - Hardware specs and revision history
  - Known issues and workarounds
  - Community ports and builds

- Armbian PineBook Pro images: https://www.armbian.com/pinebook-pro/
  - Reference build system and tested configurations
  - Hardware validation checklist

## Recommended upstream flow

This project assumes a normal ChromiumOS (Chrome OS) development workflow:

1. Prepare a Linux build machine.
2. Install the supported ChromiumOS build dependencies.
3. Fetch the ChromiumOS source tree and manifests from the official repos.
4. Add a custom board definition for PineBook Pro / RK3399.
5. Configure the kernel, bootloader, and firmware overlays for your storage target.
6. Build a recovery image and test on real hardware.

## Current status

This is a basic scaffold for early-stage porting work. The repository does not yet contain a complete vendor tree, U-Boot configuration, or final kernel patches required for a production-ready ChromiumOS image.

## Planned areas

- RK3399 enabled board definition
- Storage-specific kernel configs (eMMC, microSD, NVMe)
- Device tree overlays for each storage backend
- Display / touch / keyboard fixes
- Wi-Fi/Bluetooth support notes
- Recovery image and flashing guidance per storage type
- Testing checklist for PineBook Pro hardware
- Build automation scripts for all three storage targets

## Getting started

On Linux or in WSL2:

```bash
build/linux/preflight.sh
build/linux/sync.sh
build/linux/build.sh
build/linux/flash-microsd.sh /dev/sdX
```

From Windows: `.\build\windows\Start-PinebookBuild.ps1`.

See [build/README.md](build/README.md) for stages and settings and
[docs/WINDOWS_BUILD.md](docs/WINDOWS_BUILD.md) for the WSL2 setup. `setup_board`
for this board needs the board overlay in
`boards/pinebook-pro-rk3399/overlay-pinebook-pro-rk3399/`; see
[docs/STORAGE.md](docs/STORAGE.md) and [docs/PORTING_GUIDE.md](docs/PORTING_GUIDE.md).


