# How the port is put together

ChromiumOS supports a new board through a board overlay: a Portage overlay
that says how to build the kernel, which firmware and drivers to install,
and how to lay out the disk. This document walks through this port's
overlay, the boot flow, and the problems the Pinebook Pro raised on the way
to a working desktop, for anyone changing it or porting another RK3399
device.

## The pieces

| Piece | Where | What it does |
|-------|-------|--------------|
| Board overlay | `boards/pinebook-pro-rk3399/overlay-pinebook-pro-rk3399/` | Everything below. `build.sh overlay` copies it to `~/chromiumos/src/overlays/`, where `setup_board --board=pinebook-pro-rk3399` finds it |
| Base | `profiles/base/parent`, `metadata/layout.conf` | Inherits `arm64-generic`: a buildable generic arm64 board (unibuild config, GLES, the usual ChromeOS packages) |
| Toolchain | `toolchain.conf` | `aarch64-cros-linux-gnu`, plus `arm-none-eabi` for the Cortex-M0 firmware inside TF-A |
| Board settings | `profiles/base/make.defaults` | Kernel 6.6 with device tree, Panfrost, CPU flags, firmware, USE flags for no TPM, Crostini, Waydroid, no overlays |
| Kernel | `kernel/`, `profiles/base/profile.bashrc` | ChromeOS kernel 6.6 plus `kernel/pinebook-pro.config`, the upstream device tree, `Image` and dtb in `/boot/pinebook-pro/` ([DRIVERS_FIRMWARE.md](DRIVERS_FIRMWARE.md)) |
| Disk layout | `scripts/disk_layout.json` | 16 MiB RWFW for U-Boot, ext4 ROOT-A, 5 GiB STATE ([STORAGE.md](STORAGE.md)) |
| Boot loader | `sys-boot/pinebook-pro-u-boot`, `../install-u-boot.sh` | Upstream U-Boot 2024.10 with TF-A 2.10, written at sector 64 when the image is exported |
| BSP | `chromeos-base/chromeos-bsp-pinebook-pro-rk3399` | `boot.scr`, sound (UCM), video device names (udev), boot logs, log collector, STATE grow |
| `virtual/chromeos-bsp` | version 3 | Pulls in the BSP (and Waydroid). It must stay above arm64-generic's version 2, and `profiles/base/package.mask` masks that one, so the build stops instead of quietly using it |
| Graphics | `virtual/opengles`, `minigbm/panfrost.c` | Mesa Panfrost, and a Panfrost backend for minigbm |
| Firmware | `sys-firmware/ap6256-firmware` | Wi-Fi and Bluetooth files for the AP6256 |
| Apps | `chromeos-base/pinebook-control`, `chromeos-base/pinebook-waydroid` and the Waydroid stack | The Pinebook app, Google keys, moving the system; Android ([WAYDROID.md](WAYDROID.md)) |

The overlay's [README](../boards/pinebook-pro-rk3399/overlay-pinebook-pro-rk3399/README.md)
lists it file by file.

## Boot flow

1. The RK3399 boot ROM starts a U-Boot: Manjaro's on the eMMC (the path
   used on the project's laptop), or the card's when the eMMC has none
   ([STORAGE_STRATEGY.md](STORAGE_STRATEGY.md#how-each-disk-boots)).
2. U-Boot runs `boot.scr`: our `bootcmd` loads `/boot/pinebook-pro/boot.scr`
   from ROOT-A; Manjaro's finds the copy in the root of EFI-SYSTEM.
3. `boot.scr` hands over to the eMMC or SSD copy if the system was moved;
   otherwise it loads `Image` and the device tree from ROOT-A, sets the GPU
   compatible, applies `pinebook-tune.scr` if present, builds the command line
   and runs `booti`.
4. The kernel mounts ROOT-A by PARTUUID, read-only, and starts upstart. Along
   ChromiumOS's own jobs:

| Job | Starts | Does |
|-----|--------|------|
| `pinebook-boot-logs` | `start on startup` | Logs every boot to EFI-SYSTEM and FAT USB drives |
| `pinebook-migrate` | `start on starting startup` | Moves the system to another disk, only when `pinebook.migrate=1` |
| `pinebook-grow-stateful` | `start on started boot-services` | Grows STATE into the card, once |
| `pinebook-chrome-keys` | `start on starting ui` | Gives Chrome the Google API keys and video logging flags |
| `pinebook-control` | `start on started system-services` | The Pinebook app's service |
| `pinebook-android` | at login | Android's service ([WAYDROID.md](WAYDROID.md)) |

## From the first build to a working desktop

The order in which the laptop's problems showed up and were fixed, so that
the reasons behind the overlay's settings are not lost:

| Date | Problem | Fix |
|------|---------|-----|
| 2026-10-06 | `build_image` failed under WSL2: the WSL2 kernel's ext2 has no extended attributes for SELinux labels | ROOT-A as ext4 without a journal |
| 2026-10-06 | arm64-generic's `package.use` was undone by copying its USE flags into the board profile | `make.defaults` starts with `USE=""` |
| 2026-10-06 | The image had no boot loader | `install-u-boot.sh` at export, inside a 16 MiB RWFW |
| 2026-10-11 | Manjaro's U-Boot on the eMMC starts first and never looked at ROOT-A | `boot.scr` also in the root of EFI-SYSTEM, which its standard boot scans |
| 2026-10-11 | The boot did not reach the desktop, and there was no serial cable to see why | `pinebook-boot-logs`: logs to EFI-SYSTEM, readable from Windows |
| 2026-10-11 | Reboot loop: `chromeos_startup` could not load the TPM system key | `-encrypted_stateful` |
| 2026-10-12 | `chromeos_startup` exited silently, found by tracing it (`pinebook-startup-trace`): it opened `/dev/tpm0` to extend a PCR | `tpm_insecure_fallback` |
| 2026-10-12 | Boot logo forever: Chrome found no GPU | Panfrost built in, and `boot.scr` sets the compatible the ChromeOS kernel's Panfrost binds to |
| 2026-10-12 | Wi-Fi did not connect (`disconnect-failure`) | `brcmfmac.feature_disable=0x82000`: the handshake stays in `wpa_supplicant` |
| 2026-10-12 | Login broke after `trunksd` was disabled | Change reverted: cryptohome needs the TPM services, a crashing `trunksd` is harmless |
| 2026-10-12 | The Camera app made Chrome eat all memory in display buffers | `set_hw_overlay_strategy_none` |
| 2026-10-12 | Google sign-in failed: a Chromium build has no API keys | `pinebook-chrome-keys` and your own keys |
| 2026-10-12 | 5 GB STATE on a 64 GB card | `pinebook-grow-stateful`, leaving 25 GiB for Android |
| 2026-10-13 | Video decoded on the CPU: Chrome found no `/dev/video-dec0`, and minigbm had no backend for Panfrost | udev names and `minigbm/panfrost.c`; Chrome still decodes on the CPU, investigation continues |
| 2026-10-13 | Android's container did not start: LXC's root mount point was under `/var`, which the image cannot ship | LXC built with `/usr/lib/lxc/rootfs`; waiting for a test |
| 2026-10-13 | YouTube live streams did not play: the prebuilt Chromium has no H.264 or AAC | Chrome built from source with `chrome_media` |

## Lessons

For the SDK's own rules (EAPI 7, `oom score`, nothing under `/var`,
Manifests), see
[build/README.md](../build/README.md#rules-the-sdk-taught-us). Beyond those:

- **Logs first.** Without a serial cable, the boot logs on a FAT partition
  were what made each fix possible. `printk.devkmsg=on` keeps userspace
  messages in the kernel log, and `hung_task_panic=0` turns a hang into a
  stack trace instead of a reboot.
- **No TPM means two USE flags, not removed services.** ChromeOS expects a
  TPM everywhere; `-encrypted_stateful` and `tpm_insecure_fallback` are
  enough.
- **The SDK refuses host tools under their plain names.** U-Boot and TF-A
  get `cros_allow_gnu_build_tools` and prefixed compilers; the kernel hook
  passes the same tools `cros-kernel` uses.
- **Read-only sources.** minigbm builds out of tree from the checkout, so the
  hook builds a private copy with the Panfrost backend.
- **Upstream first.** The device tree, U-Boot and TF-A are upstream releases
  used as they are, so later upgrades stay simple.

## Porting another RK3399 device

The same structure works for other RK3399 laptops and boards:

1. Copy the overlay under a new board name: the directory, `repo-name` in
   `metadata/layout.conf`, `profiles/repo_name`, and `BOARD_NAME` in
   `board.conf`.
2. Point the kernel hook and `boot.scr` at the device's upstream `.dtb`.
3. Check the kernel fragment against the device's chips (PMIC, codec, Wi-Fi,
   panel).
4. Use the device's U-Boot defconfig in `sys-boot/pinebook-pro-u-boot`.
5. Replace the Wi-Fi firmware, the UCM files and, if the device has other
   video blocks, the udev names.
