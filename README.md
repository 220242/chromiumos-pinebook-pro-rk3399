# ChromiumOS for the Pinebook Pro (RK3399)

A ChromiumOS port for the Pine64 Pinebook Pro (Rockchip RK3399): a board
overlay for the ChromiumOS SDK, build scripts for Linux and for Windows
(WSL2), and tools that run on the laptop: the **Pinebook** app (hardware
monitor, power modes, overclocking, moving the system to the eMMC or an NVMe
SSD) and **Android** apps through Waydroid.

The image boots from a microSD card. The eMMC (with Manjaro on a factory
laptop) is not touched until you move the system there yourself.

## Status

Test image, built from this repository on a Windows PC (WSL2) and run on a
Pinebook Pro from microSD. State on 2026-10-14; the full list per component
is in [docs/HARDWARE.md](docs/HARDWARE.md).

| | |
|---|---|
| **Works on the laptop** | Boot from microSD (through Manjaro's U-Boot on the eMMC); login screen, Guest mode and Google accounts (with your own Google API keys); display and GPU (Panfrost on the Mali-T860); keyboard, touchpad, lid switch, power button; Wi-Fi; the Bluetooth adapter is detected; the stateful partition grows to the card's size; the Pinebook app; VP9 video (decoded on the CPU) |
| **In progress** | Chrome built from source with H.264, AAC and the other proprietary codecs, for YouTube live streams (the prebuilt Chromium has none of them); hardware video decoding (Chrome still decodes on the CPU); Android: setup downloads it, the fix for starting its container is waiting for a test |
| **Built in, not confirmed yet** | The card's own U-Boot, for a laptop without a boot loader on the eMMC; sound (CRAS finds the speakers, headphones and microphone); Linux (Crostini: `/dev/kvm` is there, not started yet); moving the system to the eMMC or an NVMe SSD (tested on disk images only); webcam |
| **Not checked** | Suspend and resume, brightness and volume keys; USB-C display output, which is not expected to work yet ([display notes](docs/HARDWARE.md#display-and-gpu)) |

## Quick start

1. **Get an image.** There is no published download; build one with
   [build/README.md](build/README.md) (on Windows:
   [docs/WINDOWS_BUILD.md](docs/WINDOWS_BUILD.md)). The first build takes
   many hours, mostly for Chrome.
2. **Write it to a microSD card** of 64 GB or more with balenaEtcher, Rufus
   or `build/linux/flash-microsd.sh`. The image file is about 7.9 GB; it fits
   a 16 GB card, but on cards of 32 GB and less the partition for your data
   stays at 5 GB.
3. **Boot the laptop** with the card in. The first boot grows the system
   partition into the card. Log in as a guest, or with a Google account after
   putting your own Google API keys on the card.

Everything after that (Google sign-in, the Pinebook app, Android, logs,
troubleshooting) is in [docs/USER_GUIDE.md](docs/USER_GUIDE.md).

## Documentation

| Document | What it covers |
|----------|----------------|
| [docs/USER_GUIDE.md](docs/USER_GUIDE.md) | Writing the card, first boot, Google sign-in, the Pinebook app, logs, troubleshooting |
| [docs/HARDWARE.md](docs/HARDWARE.md) | What works on the laptop, component by component, and what is next for each |
| [docs/WAYDROID.md](docs/WAYDROID.md) | Android apps: setup, Google Play, how it works, what is unverified |
| [docs/INSTALL_TO_EMMC_NVME.md](docs/INSTALL_TO_EMMC_NVME.md) | Moving the system from the card to the eMMC or an NVMe SSD |
| [build/README.md](build/README.md) | The build scripts: stages, the fast `patch` path, settings, Chrome from source |
| [docs/WINDOWS_BUILD.md](docs/WINDOWS_BUILD.md) | Building on Windows 11 with WSL2, writing the card from Windows |
| [docs/PORTING_GUIDE.md](docs/PORTING_GUIDE.md) | How the port is put together: overlay, kernel, U-Boot, boot flow, the fixes the hardware needed |
| [docs/DRIVERS_FIRMWARE.md](docs/DRIVERS_FIRMWARE.md) | Kernel options, firmware, graphics, video and sound userspace |
| [docs/STORAGE.md](docs/STORAGE.md) | Disks, device names, the partition layout, files on EFI-SYSTEM |
| [docs/STORAGE_STRATEGY.md](docs/STORAGE_STRATEGY.md) | Why microSD first, how each disk boots, updates and recovery |
| [docs/HARDWARE_SPECS.md](docs/HARDWARE_SPECS.md) | The Pinebook Pro's hardware as Linux sees it |
| [docs/BUILD_PLAN.md](docs/BUILD_PLAN.md) | What has been done, what is in progress, what is next |
| [boards/pinebook-pro-rk3399/overlay-pinebook-pro-rk3399/README.md](boards/pinebook-pro-rk3399/overlay-pinebook-pro-rk3399/README.md) | The board overlay, file by file |
| [sources/UPSTREAM_SOURCES.md](sources/UPSTREAM_SOURCES.md) | Upstream projects and versions used, and references |

## Repository layout

```text
.
├── boards/pinebook-pro-rk3399/
│   ├── board.conf                     BOARD_NAME, read by the build scripts
│   ├── install-u-boot.sh              puts U-Boot and boot.scr into a built image
│   ├── overlay-pinebook-pro-rk3399/   the ChromiumOS board overlay (the port itself)
│   ├── kernel-config/                 early per-disk kernel fragments, reference only
│   └── overlays/                      early device tree overlays, reference only
├── build/
│   ├── linux/                         preflight, sync, build, flash-microsd
│   └── windows/                       Start-PinebookBuild.ps1 (runs the Linux scripts in WSL2)
├── docs/                              see the table above
├── scripts/check-dts.sh               compiles boards/*/overlays/*.dts against the upstream device tree
└── sources/UPSTREAM_SOURCES.md
```

The build uses only the board overlay: its own kernel fragment
(`kernel/pinebook-pro.config`) and the upstream device tree. `kernel-config/`
and `overlays/` are from the first planning stage and are not part of any
image; `scripts/check-dts.sh` still checks that the overlays compile.

## License

Apache License 2.0 ([LICENSE](LICENSE)). Files that say otherwise in their
header keep their own license: the ebuilds and scripts in the overlay are
GPL-2, as usual for Gentoo and ChromiumOS packages, and the minigbm backend is
BSD.
