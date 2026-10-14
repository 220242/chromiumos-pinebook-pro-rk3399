# overlay-pinebook-pro-rk3399

The ChromiumOS board overlay for the Pinebook Pro (Rockchip RK3399), board
name `pinebook-pro-rk3399` (`BOARD_NAME` in `../board.conf`).

`build/linux/build.sh overlay` copies this directory to
`~/chromiumos/src/overlays/overlay-pinebook-pro-rk3399/`, after which
`setup_board --board=pinebook-pro-rk3399` finds the board.

**Status:** builds in the ChromiumOS SDK (`stable` manifest branch) and
boots on the Pinebook Pro from microSD to the desktop. What works, part by
part: [docs/HARDWARE.md](../../../docs/HARDWARE.md). How the pieces fit
together and why: [docs/PORTING_GUIDE.md](../../../docs/PORTING_GUIDE.md).

## Contents

| Path | What it does |
|------|--------------|
| `metadata/layout.conf`, `profiles/repo_name`, `profiles/categories` | Overlay metadata, repo name `pinebook-pro-rk3399`; `arm64-generic` is one of the masters |
| `toolchain.conf` | `aarch64-cros-linux-gnu`, plus `arm-none-eabi` for the RK3399 Cortex-M0 firmware inside TF-A |
| `profiles/base/parent` | `arm64-generic:base`: unibuild config, GLES and the rest of a buildable arm64 board |
| `profiles/base/make.defaults` | ChromeOS kernel 6.6 with `device_tree` and the `chromiumos-rockchip64` splitconfig; CPU flags; `VIDEO_CARDS` Panfrost; firmware (`rockchip-dptx`, no Intel Wi-Fi); USE flags: no VKMS, no TPM (`-encrypted_stateful`, `tpm_insecure_fallback`), Crostini (`kvm_host`), Waydroid, no hardware overlays in Chrome |
| `profiles/base/package.use` | dnsmasq with DHCP for Android's network; Chrome built from source with `chrome_media`, `hevc_codec` and `subpixel_rendering`, without tests or debug info |
| `profiles/base/package.mask` | Masks arm64-generic's `virtual/chromeos-bsp`, so the build stops if the board's cannot be installed instead of using that one |
| `profiles/base/profile.bashrc` | Hooks: merge `kernel/pinebook-pro.config` into the kernel config and install `Image` and the device tree to `/boot/pinebook-pro/`; build minigbm with the Panfrost backend |
| `kernel/pinebook-pro.config` | Kernel fragment for the upstream `rk3399-pinebook-pro.dts` |
| `kernel/apply-fragment.sh` | Merges the fragment, runs `olddefconfig`, fails if a symbol was dropped |
| `minigbm/panfrost.c` | minigbm backend for Panfrost's render node, where Chrome allocates its buffers |
| `scripts/disk_layout.json` | `legacy_disk_layout.json` with a 16 MiB RWFW (U-Boot at sector 64 fits inside it), 64 MiB kernel partitions, 128 MiB EFI-SYSTEM, ext4 ROOT-A without a journal, 5 GiB STATE |
| `virtual/chromeos-bsp` | Version 3 (above arm64-generic's): the board BSP, and `pinebook-waydroid` with USE `waydroid` |
| `virtual/opengles` | Mesa Panfrost (`media-libs/mesa-panfrost`) for the Mali-T860 |
| `chromeos-base/chromeos-bsp-pinebook-pro-rk3399` | The board support package, below |
| `chromeos-base/pinebook-control` | The Pinebook app, Google API keys for Chrome, moving the system, below |
| `chromeos-base/pinebook-waydroid` | Android apps: the `pinebook-android` service, the page http://android.localhost (the **Android** app in the launcher) and the `android` command; see [docs/WAYDROID.md](../../../docs/WAYDROID.md) |
| `app-containers/waydroid` | Waydroid 1.6.3 without systemd, AppArmor, seccomp or PyGObject (`files/gi` stands in for the parts of GLib it uses) |
| `app-containers/lxc` | LXC 7.0.0 for Waydroid's container, without AppArmor, seccomp, SELinux or systemd, its root mount point under `/usr` |
| `dev-libs/libglibutil`, `dev-libs/gbinder`, `dev-python/gbinder` | libgbinder and its Python module, Waydroid's binder client |
| `sys-boot/pinebook-pro-u-boot` | Upstream U-Boot 2024.10, `pinebook-pro-rk3399_defconfig` plus `files/chromiumos.config`, with TF-A 2.10.0 BL31; installed into the board sysroot only |
| `sys-firmware/ap6256-firmware` | AP6256 (BCM43456) Wi-Fi firmware, CLM blob, NVRAM and Bluetooth patch, from a pinned Armbian commit |

`../install-u-boot.sh` writes the boot loader into a built image and copies
`boot.scr` to EFI-SYSTEM; `build.sh export` runs it.

### The board support package

`chromeos-bsp-pinebook-pro-rk3399` installs:

| File | What it is |
|------|------------|
| `/boot/pinebook-pro/boot.scr` | The U-Boot script, from `files/boot.cmd` ([docs/DRIVERS_FIRMWARE.md](../../../docs/DRIVERS_FIRMWARE.md#kernel-command-line)) |
| `/etc/init/pinebook-boot-logs.conf`, `/usr/sbin/pinebook-boot-logs` | Every boot's logs to `logs/boot-NNNN/` on EFI-SYSTEM and FAT USB drives |
| `/usr/sbin/pinebook-collect` | `sudo pinebook-collect`: logs and hardware state to `logs/collect-*/` |
| `/etc/init/pinebook-grow-stateful.conf`, `/usr/sbin/pinebook-grow-stateful` | Grows STATE to the end of the card minus 25 GiB, once |
| UCM files for `rockchip,es8316-codec` | Speaker, headphones and microphone for CRAS |
| `50-media.rules` (udev) | `/dev/video-dec0` (rkvdec), `/dev/video-dec1` and `/dev/video-enc0` (Hantro) |
| `/etc/lsb-release` app ID | The board's own; `build_image` requires one |
| `/usr/sbin/pinebook-startup-trace` | Bring-up: runs `chromeos_startup` under `strace` when `files/startup.override` is installed as `/etc/init/startup.override` (it is not, now that the system boots) |

### The Pinebook app

`pinebook-control` installs:

| File | What it is |
|------|------------|
| `/etc/init/pinebook-control.conf`, `/usr/sbin/pinebook-control` | The service behind http://pinebook.localhost:8086, as root, localhost only |
| `/usr/share/pinebook-control/web/` | The page |
| `/usr/share/chromium/extensions/web_apps/pinebook-control.json` | The **Pinebook** launcher icon, preinstalled for every profile |
| `/etc/init/pinebook-chrome-keys.conf`, `/usr/sbin/pinebook-chrome-keys` | Before every start of the UI: Google API keys from `google-api-keys.txt` on EFI-SYSTEM (or from the app) and video logging flags into Chrome's environment |
| `/etc/init/pinebook-migrate.conf`, `/usr/sbin/pinebook-migrate` | Moving the system to the eMMC or an NVMe SSD ([docs/INSTALL_TO_EMMC_NVME.md](../../../docs/INSTALL_TO_EMMC_NVME.md)) |

## Building

The build scripts do all of this ([build/README.md](../../../build/README.md)).
By hand, inside the SDK:

```bash
setup_board --board=pinebook-pro-rk3399
cros build-packages --board=pinebook-pro-rk3399
cros build-image --board=pinebook-pro-rk3399 --no-enable-rootfs-verification test

# Outside the SDK: put the boot loader into the image, then write it to the card.
boards/pinebook-pro-rk3399/install-u-boot.sh ~/chromiumos/src/build/images/pinebook-pro-rk3399/latest/chromiumos_test_image.bin
```

Rootfs verification must be off: there is no verified boot on this board,
and only ROOT-A boots.

Packages that download sources have their `Manifest` committed here, because
`build.sh overlay` copies the overlay with `rsync --delete`. After changing
such a package's sources, regenerate it inside the SDK and commit it:

```bash
ebuild ~/chromiumos/src/overlays/overlay-pinebook-pro-rk3399/sys-boot/pinebook-pro-u-boot/pinebook-pro-u-boot-2024.10.ebuild manifest
```

## Known gaps

- Hardware video decoding: the devices and the minigbm backend are there,
  Chrome still decodes on the CPU.
- USB-C display output: `cdn-dp` is disabled in the 6.6 device tree.
- No A/B updates and no update that keeps the user's data.
- The SPI flash is not used (`u-boot-rockchip-spi.bin` is built and
  installed into the sysroot, nothing writes it).
