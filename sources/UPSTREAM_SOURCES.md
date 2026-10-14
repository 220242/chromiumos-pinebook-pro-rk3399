# Upstream sources

What the image is built from, with the versions in use on 2026-10-14, and
the references that helped.

## Used in the build

| Component | Version | Source |
|-----------|---------|--------|
| ChromiumOS | `stable` manifest branch, Chrome 157 | [chromiumos/manifest](https://chromium.googlesource.com/chromiumos/manifest), synced by `build/linux/sync.sh` |
| Kernel | ChromeOS kernel 6.6 (6.6.147 in the current image) | [chromiumos/third_party/kernel](https://chromium.googlesource.com/chromiumos/third_party/kernel/), `sys-kernel/chromeos-kernel-6_6` from the checkout |
| Device tree | `rk3399-pinebook-pro.dts` of that kernel, unchanged | [upstream Linux](https://github.com/torvalds/linux/blob/v6.6/arch/arm64/boot/dts/rockchip/rk3399-pinebook-pro.dts) |
| U-Boot | v2024.10, `pinebook-pro-rk3399_defconfig` | [u-boot/u-boot](https://github.com/u-boot/u-boot) release tarball |
| TF-A | v2.10.0, `PLAT=rk3399` | [ARM-software/arm-trusted-firmware](https://github.com/ARM-software/arm-trusted-firmware) release tarball |
| Wi-Fi and Bluetooth firmware | Armbian firmware commit `2a9e1c1` (2026-09-10) | [armbian/firmware](https://github.com/armbian/firmware), `brcm/` |
| DisplayPort firmware | `rockchip/dptx.bin` | linux-firmware, through ChromiumOS's `LINUX_FIRMWARE` |
| Mesa | ChromiumOS's `media-libs/mesa-panfrost` (23.3 in the current image) | the ChromiumOS checkout |
| Waydroid | 1.6.3 | [waydroid/waydroid](https://github.com/waydroid/waydroid) |
| LXC | 7.0.0 | [lxc/lxc](https://github.com/lxc/lxc) |
| libgbinder | 1.1.52 | [mer-hybris/libgbinder](https://github.com/mer-hybris/libgbinder) |
| libglibutil | 1.0.82 | [sailfishos/libglibutil](https://github.com/sailfishos/libglibutil) |
| gbinder-python | 1.3.1 | [waydroid/gbinder-python](https://github.com/waydroid/gbinder-python) |
| Android images | LineageOS 20 (Android 13), downloaded by Waydroid on the laptop | Waydroid's update server, `ota.waydro.id` |

The release tarballs are listed with their hashes in the `Manifest` of each
package in the overlay.

## References

- [ChromiumOS developer guide](https://www.chromium.org/chromium-os/developer-library/guides/development/developer-guide/):
  the SDK, `setup_board`, `build_packages`, `build_image`
- [ChromiumOS disk format](https://www.chromium.org/chromium-os/chromiumos-design-docs/disk-format/):
  partitions and the stateful partition
- [Chromium API keys](https://www.chromium.org/developers/how-tos/api-keys/):
  Google sign-in for Chromium builds
- [Pine64 wiki: Pinebook Pro](https://wiki.pine64.org/wiki/Pinebook_Pro):
  hardware, schematics, the serial console
- [Linux media: rkvdec](https://github.com/torvalds/linux/tree/v6.6/drivers/staging/media/rkvdec)
  and [Hantro](https://github.com/torvalds/linux/tree/v6.6/drivers/media/platform/verisilicon):
  which codecs the RK3399's video blocks support in 6.6
- [Mesa Panfrost](https://docs.mesa3d.org/drivers/panfrost.html)
- [Waydroid documentation](https://docs.waydro.id/)
- A working mainline kernel config for another RK3399 board, the Khadas
  Edge-V, was the reference for the SoC options in the kernel fragment.
