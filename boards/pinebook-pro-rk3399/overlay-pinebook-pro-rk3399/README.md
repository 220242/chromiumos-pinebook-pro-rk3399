# overlay-pinebook-pro-rk3399

Draft ChromiumOS board overlay for the Pinebook Pro (Rockchip RK3399), board
name `pinebook-pro-rk3399` (`BOARD_NAME` in `../board.conf`).

`build/linux/build.sh overlay` copies this directory to
`~/chromiumos/src/overlays/overlay-pinebook-pro-rk3399/`, after which
`setup_board --board=pinebook-pro-rk3399` can find the board.

**Status: not built yet.** Nothing here has been through `setup_board`,
`build_packages` or `build_image`. See "What was checked" below.

## Contents

| Path | What it does |
|------|--------------|
| `metadata/layout.conf`, `profiles/repo_name` | Overlay metadata, repo name `pinebook-pro-rk3399` |
| `toolchain.conf` | `aarch64-cros-linux-gnu`, plus `arm-none-eabi` for the RK3399 Cortex-M0 firmware inside TF-A |
| `profiles/base/parent` | Generic ChromiumOS arm64 profile (64-bit userland) |
| `profiles/base/make.defaults` | ChromeOS kernel 6.6, `device_tree`, `rockchip64` splitconfig, Panfrost, CPU flags |
| `profiles/base/profile.bashrc` | Hooks on `sys-kernel/chromeos-kernel-*`: merge `kernel/pinebook-pro.config`, install `Image` and the device tree to `/boot/pinebook-pro/` |
| `kernel/pinebook-pro.config` | Kernel fragment for the upstream `rk3399-pinebook-pro.dts` |
| `kernel/apply-fragment.sh` | Merges the fragment, runs `olddefconfig`, fails if a symbol was dropped |
| `scripts/disk_layout.json` | Grows RWFW (partition 11) to 16 MiB so the boot loader at sector 64 fits inside it |
| `virtual/chromeos-bsp` | Pulls in the board BSP |
| `chromeos-base/chromeos-bsp-pinebook-pro-rk3399` | U-Boot boot script (`/boot/pinebook-pro/boot.scr`); depends on the firmware and U-Boot |
| `sys-boot/pinebook-pro-u-boot` | Upstream U-Boot v2024.10, `pinebook-pro-rk3399_defconfig` + `files/chromiumos.config`, with TF-A v2.10.0 BL31 |
| `sys-firmware/ap6256-firmware` | AP6256 (BCM43456) Wi-Fi firmware, CLM blob, NVRAM and Bluetooth patch, pinned Armbian commit |

`../install-u-boot.sh` writes the built boot loader into a disk image.

## Hardware assumptions

AMPAK AP6256 Wi-Fi/Bluetooth (brcmfmac over SDIO, Bluetooth over UART),
ES8316 audio codec, 4 GB RAM, eMMC on SDHCI Arasan, microSD on DW MMC, one
PCIe controller (pcie0) for the NVMe adapter. The device tree is the upstream
Linux `arch/arm64/boot/dts/rockchip/rk3399-pinebook-pro.dts`, used as is; the
`../overlays/*.dts` fragments are not used by this overlay.

## Boot flow (microSD first)

1. RK3399 boot ROM loads `u-boot-rockchip.bin` (TPL/SPL + U-Boot + BL31) from
   sector 64 of the microSD card.
2. U-Boot's `bootcmd` loads `/boot/pinebook-pro/boot.scr` from partition 3
   (ROOT-A) of the microSD card (`mmc 1`), then the eMMC (`mmc 0`). If neither
   has one it falls back to `bootflow scan`.
3. `boot.scr` loads `Image` and `rk3399-pinebook-pro.dtb` from the same
   partition and boots with `root=PARTUUID=<ROOT-A>`.

There is no verified boot and no A/B kernel switching: only ROOT-A boots, and
the image has to be built with `--no-enable-rootfs-verification` (build.sh
already passes it).

## Building

```bash
# Inside the SDK, once per change to the U-Boot ebuild (see "Manifests"):
ebuild ~/chromiumos/src/overlays/overlay-pinebook-pro-rk3399/sys-boot/pinebook-pro-u-boot/pinebook-pro-u-boot-2024.10.ebuild manifest

setup_board --board=pinebook-pro-rk3399
cros build-packages --board=pinebook-pro-rk3399
cros build-image --board=pinebook-pro-rk3399 --no-enable-rootfs-verification test

# Outside the SDK: put the boot loader into the image, then write it to the card.
boards/pinebook-pro-rk3399/install-u-boot.sh ~/chromiumos/src/build/images/pinebook-pro-rk3399/latest/chromiumos_test_image.bin
```

### Manifests

`sys-firmware/ap6256-firmware/Manifest` is generated from the actual files.
`sys-boot/pinebook-pro-u-boot` has no Manifest yet: the U-Boot and TF-A
release tarballs could not be downloaded where this overlay was written, and a
guessed hash is worse than none. Generate it with the `ebuild ... manifest`
command above and commit it to this repo (build.sh copies the overlay with
`rsync --delete`, so a Manifest that exists only in the checkout is lost).

## What was checked

Outside a ChromiumOS checkout, on Linux 6.6.50, U-Boot v2024.10 and TF-A
v2.10.0:

- `kernel/pinebook-pro.config` merged onto arm64 `defconfig` with
  `apply-fragment.sh`: every symbol survives `olddefconfig`.
- `rk3399-pinebook-pro.dtb` builds from the upstream source with `dtc`.
- The kernel `Image` builds with that config (aarch64 GCC cross compiler).
- TF-A BL31 for `rk3399` (including the M0 firmware) and U-Boot with
  `files/chromiumos.config` build; the resulting `bootcmd` is the one above.
- `boot.cmd` compiles with `mkimage` and runs in U-Boot's sandbox against a
  GPT test image, loading the script, kernel and device tree from partition 3.
- `install-u-boot.sh` writes the loader into a test GPT image with a 16 MiB
  RWFW and refuses an image whose next partition overlaps the loader.
- Shell scripts pass `bash -n` and `shellcheck`; ebuilds pass `bash -n`.

## Not checked (needs a real ChromiumOS checkout)

- `setup_board`/`build_packages`/`build_image` for this board.
- That the ChromeOS kernel 6.6 has the `chromiumos-rockchip64` splitconfig
  flavour (fallback: `chromiumos-arm64-generic`) and that the fragment applies
  on top of it.
- The `profile.bashrc` hooks: the `cros_post_src_configure_*` and
  `cros_post_src_install_*` names, and how they find the kernel build
  directory, follow the ChromiumOS hook convention but have not run.
- That `disk_layout.json` inherits from `common_disk_layout.json` this way and
  that RWFW really starts at sector 64; `install-u-boot.sh` checks the result
  on every image.
- U-Boot and TF-A built with the SDK's toolchain (`${CHOST}-` and
  `arm-none-eabi-`) instead of the GCC cross compilers used here.
- Anything on the hardware.

## Known gaps

- No TPM: cryptohome/login may need extra USE flags or a TPM simulator.
- No ALSA UCM config for CRAS (ES8316 speaker/headphone switching).
- No touchpad/keyboard tuning, no Chrome OS EC: power button and lid come from
  `gpio-keys`.
- eMMC and NVMe install paths, SPI flash U-Boot
  (`u-boot-rockchip-spi.bin` is built and installed but not used yet).
