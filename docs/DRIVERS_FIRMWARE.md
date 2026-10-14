# Drivers and firmware

What the image runs on the Pinebook Pro's hardware: the kernel and its
options, the device tree, firmware files, and the userspace pieces for
graphics, video and sound. All of it lives in the board overlay,
`boards/pinebook-pro-rk3399/overlay-pinebook-pro-rk3399/` (called "the
overlay" below). What works is in [HARDWARE.md](HARDWARE.md).

## Kernel

- **Source:** the ChromeOS kernel 6.6 (`sys-kernel/chromeos-kernel-6_6`;
  6.6.147 in the current image), selected in `profiles/base/make.defaults`.
- **Config:** ChromeOS's `chromiumos-rockchip64` splitconfig (the RK3399
  Chromebooks' config) plus the overlay's `kernel/pinebook-pro.config`.
  `profiles/base/profile.bashrc` merges the fragment after the kernel's
  configure step with `kernel/apply-fragment.sh`, which runs `olddefconfig`
  and stops the build if any option of the fragment was dropped.
- **Device tree:** the kernel's own `rk3399-pinebook-pro.dts`, unchanged.
  `boot.scr` makes two changes at boot (below).
- **Install:** the same hook installs `Image` and `rk3399-pinebook-pro.dtb`
  into `/boot/pinebook-pro/` on ROOT-A, next to `boot.scr`. There is no
  initramfs: what is needed to mount the root file system is built in.

Portage does not notice a changed fragment, so after editing it rebuild the
kernel explicitly: `emerge-pinebook-pro-rk3399 sys-kernel/chromeos-kernel-6_6`
([build/README.md](../build/README.md#which-build-for-which-change)).

### What the fragment adds

| Group | Options | Built |
|-------|---------|-------|
| SoC | clocks, pin control, GPIO, power domains, IOMMU, thermal, SARADC, eFuse, PWM, I2C, SPI, UART, cpufreq, DMC devfreq, CPU idle, watchdog, PL330 DMA | in |
| PMIC | RK808 (regulators, RTC, clock), SYR827/828 (`fan53555`), PWM and fixed regulators | in |
| Storage | SDHCI Arasan (eMMC) with its PHY, DW MMC (microSD, SDIO), PCIe host and PHY, NVMe, SPI NOR, ext4 (also for ext2), FAT | in |
| USB | xHCI/DWC3, EHCI, OHCI, the USB2 and Type-C PHYs, Type-C with TCPM and FUSB302, DisplayPort alt mode, HID with multitouch, USB storage | in |
| Display | DRM with the Rockchip VOP, Analogix eDP, CDN DisplayPort, `panel-edp`, PWM backlight, Panfrost | in |
| Video | Hantro VPU, RGA, rkvdec (staging) | modules |
| Sound | Rockchip I2S, ES8316, simple amplifier, simple-audio-card | in |
| Wi-Fi, Bluetooth | cfg80211, brcmfmac (SDIO), Bluetooth with `hci_uart` and `hci_bcm` over serdev | modules (they load firmware from the root file system) |
| Power, input | CW2015 fuel gauge, GPIO charger, GPIO keys, GPIO LEDs | in |
| Android (Waydroid) | binder and binderfs, PSI, namespaces, freezer cgroup, veth, bridge with NAT and iptables, TUN, overlayfs, loop, FUSE, sync files, DMA-BUF heaps | in |

Panfrost is built in on purpose: as a module it was never loaded on the
laptop, so Mesa found no render node and Chrome did not start (the boot logo
stayed). Several SoC options came from a working mainline config for
another RK3399 board, the Khadas Edge-V.

### Kernel command line

`boot.scr` (`chromeos-base/chromeos-bsp-pinebook-pro-rk3399/files/boot.cmd`)
starts the kernel with:

| Argument | Why |
|----------|-----|
| `console=ttyS2,1500000 console=tty1` | serial console on the headphone jack, and the screen |
| `root=PARTUUID=<ROOT-A> rootwait ro noinitrd` | ROOT-A of the disk `boot.scr` came from, read-only |
| `cros_legacy cros_debug` | ChromiumOS's flags for a board booted by a plain boot loader, and debug features (the test image's shell) |
| `loglevel=7 printk.devkmsg=on` | full kernel log; without `devkmsg` most of `chromeos_startup`'s messages were dropped |
| `hung_task_panic=0 hung_task_timeout_secs=30` | report a stuck task after 30 s instead of panicking, so the boot logs can save it |
| `brcmfmac.feature_disable=0x82000` | keeps the Wi-Fi handshake in `wpa_supplicant` (no firmware supplicant, no SAE offload); without it Wi-Fi did not connect |
| `pinebook.migrate=1` | only when a move to another disk is waiting |

### Device tree changes at boot

- **GPU:** the ChromeOS kernel's Panfrost binds only to
  `"arm,mali-t860-CHROMIUM"` (the plain compatibles are left to Arm's own
  driver), so `boot.scr` sets the GPU node's compatible to
  `"rockchip,rk3399-mali", "arm,mali-t860-CHROMIUM"`.
- **Overclock and undervolt:** when the Pinebook app has written
  `pinebook-tune.scr` to EFI-SYSTEM, `boot.scr` runs it; it rewrites the
  CPU and GPU OPP tables.

## Firmware

| Files | From | For |
|-------|------|-----|
| `brcm/brcmfmac43456-sdio.bin`, `.clm_blob`, `.txt` | `sys-firmware/ap6256-firmware`: Armbian's firmware repository at a pinned commit | Wi-Fi (firmware 7.45.96.2). The NVRAM file is also linked as `brcmfmac43456-sdio.pine64,pinebook-pro.txt`, the name brcmfmac tries first |
| `brcm/BCM4345C5.hcd` | the same package | Bluetooth patch, also linked as `BCM4345C5.pine64,pinebook-pro.hcd` |
| `rockchip/dptx.bin` | linux-firmware (`LINUX_FIRMWARE="rockchip-dptx"`) | the `cdn-dp` block (DisplayPort over USB-C), off in the 6.6 device tree |
| `u-boot-rockchip.bin` | `sys-boot/pinebook-pro-u-boot` | U-Boot 2024.10 (`pinebook-pro-rk3399_defconfig` plus `files/chromiumos.config`) with TF-A 2.10 BL31, which includes the firmware of the RK3399's Cortex-M0 power manager. U-Boot's own TPL sets up the DRAM: no Rockchip binary blobs |

`LINUX_FIRMWARE` drops arm64-generic's Intel Wi-Fi firmware. The U-Boot
package also builds `u-boot-rockchip-spi.bin` for the SPI flash, which is not
used.

## Graphics

- **Mesa:** `virtual/opengles` pulls in `media-libs/mesa-panfrost`
  (ChromiumOS's Panfrost build of Mesa, 23.3 in the current image), for
  OpenGL ES on the Mali-T860. Mesa has no Vulkan driver for this GPU.
- **`VIDEO_CARDS="-llvmpipe panfrost"`**: no software renderer, no
  `rockchip` (minigbm's rockchip backend needs the old ChromeOS kernel's
  `rockchip_drm.h`).
- **minigbm:** Chrome allocates its buffers through minigbm on the first render
  node, which is Panfrost's. minigbm has no Panfrost backend, so the overlay
  adds one: `minigbm/panfrost.c`, copied into the minigbm build by a
  `profile.bashrc` hook, with `-DDRV_PANFROST`. Without it there was no
  hardware video decoding, and Chrome and the camera service fell back to
  dumb buffers.
- **No hardware overlays:** `set_hw_overlay_strategy_none`; with overlays the
  Camera app made Chrome allocate display buffers until memory ran out.

## Video

`files/50-media.rules` in the BSP names the V4L2 devices where Chrome looks
for them:

| Name | Device | Kernel 6.6 driver can |
|------|--------|-----------------------|
| `/dev/video-dec0`, `/dev/media-dec0` | rkvdec | decode H.264 and VP9 (not HEVC, which the hardware could) |
| `/dev/video-dec1`, `/dev/media-dec1` | Hantro VPU decoder | decode VP8 and MPEG-2 |
| `/dev/video-enc0` | Hantro VPU encoder | encode JPEG |

`pinebook-chrome-keys` also adds `--vmodule` options to Chrome's flags, so
`/var/log/chrome` shows how Chrome picks its decoders.

Codecs in Chrome: `profiles/base/package.use` builds Chrome from source with
`chrome_media` (H.264, AAC and the other proprietary codecs) and
`hevc_codec`; see [build/README.md](../build/README.md#chrome-from-source).

## Sound

The device tree's `simple-audio-card` joins I2S1, the ES8316 codec and the
speaker amplifier into the card `rockchip,es8316-codec`. ChromeOS's sound
server, CRAS, needs UCM files to know the card; the BSP installs them from
`files/audio-config/ucm-config/rockchip,es8316-codec/` (based on
alsa-ucm-conf's ES8316 config, in the UCM v1 form CRAS reads):

- **Speaker:** the DAC with the amplifier's "Speaker Switch" on, and the
  right channel inverted, because the two speakers are wired in opposite
  phase;
- **Headphone:** the same DAC with the speaker off; CRAS switches to it when
  the jack reports a plug;
- **Internal Mic:** the ADC from the differential input.

## Wi-Fi and Bluetooth

- **Wi-Fi:** `brcmfmac` on SDIO, with the firmware above and
  `brcmfmac.feature_disable=0x82000`.
- **Bluetooth:** `hci_uart` with the Broadcom protocol on UART0 (with
  RTS/CTS); `hci_bcm` loads the patch file at start.

## No TPM

The Pinebook Pro has no TPM, which ChromeOS normally requires:

- `-encrypted_stateful`: `/home` and `/var` are on the plain stateful
  partition (user data is still encrypted per account by cryptohome);
- `tpm_insecure_fallback`: lets the system start without `/dev/tpm0`, as on
  ChromeOS Flex.

`trunksd` crashes at boot without a TPM, which is harmless; the services
cryptohome needs (`tpm_managerd`, `chapsd`) must stay.

## Board tools

The overlay's own services and commands (boot logs, the STATE grow, the
Pinebook app, Google keys, moving the system, Android) are listed in the
[overlay's README](../boards/pinebook-pro-rk3399/overlay-pinebook-pro-rk3399/README.md).
