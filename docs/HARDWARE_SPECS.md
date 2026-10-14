# Pinebook Pro hardware

The Pinebook Pro's hardware as Linux sees it: what each part is, its driver,
and where it sits in the device tree. Taken from the upstream device tree
`arch/arm64/boot/dts/rockchip/rk3399-pinebook-pro.dts` (Linux 6.6, used
unchanged by this port) and from the logs of the project's laptop. Whether
each part works under ChromiumOS is in [HARDWARE.md](HARDWARE.md).

Every Pinebook Pro has the same mainboard, 4 GB of RAM and the same chips;
units differ in keyboard layout (ISO or ANSI) and in the eMMC module fitted.
One device tree covers all of them.

## Overview

| Part | What it is | Linux driver | Where |
|------|-----------|--------------|-------|
| SoC | Rockchip RK3399: 2x Cortex-A72 and 4x Cortex-A53 | | |
| RAM | 4 GB LPDDR4; Linux sees about 3.7 GiB | | |
| GPU | Arm Mali-T860 MP4 | `panfrost` | `gpu@ff9a0000` |
| Display | 14.1" 1920x1080 IPS panel, BOE NV140FHM-N49, over eDP | `rockchipdrm` (VOP, `analogix_dp`), `panel-edp`, `pwm-backlight` | `edp`, `edp-panel`, `edp-backlight` |
| Video | rkvdec decoder, Hantro VPU decoder and encoder, RGA 2D | `rkvdec` (staging), `hantro-vpu`, `rockchip-rga` | |
| eMMC | removable module, 64 GB standard (128 GB offered), HS200 | `sdhci-of-arasan` | `sdhci`, alias `mmc2` |
| microSD | UHS-I slot, run at SDR50 | `dwmmc_rockchip` | `sdmmc`, alias `mmc1` |
| NVMe | optional M.2 adapter board on the internal PCIe connector | `pcie-rockchip-host`, `nvme` | `pcie0` |
| SPI flash | 16 MB SPI NOR; this port does not use it | `spi-nor` | `spi1` |
| Keyboard, touchpad | one USB device, "HAILUCK CO.,LTD USB KEYBOARD" (258a:001e), with keyboard, touchpad and media key interfaces | `usbhid`, `hid-multitouch` | internal USB |
| Webcam | USB UVC camera (0c45:6321) behind an internal USB 2.0 hub (05e3:0608) | `uvcvideo` | internal USB |
| Sound | Everest ES8316 codec on I2S1, speaker amplifier, headphone jack with detection, internal microphone | `snd_soc_es8316`, `simple-audio-card` | `i2c1` 0x11 |
| Wi-Fi | AMPAK AP6256 (Broadcom BCM43456), 802.11ac, 2.4 and 5 GHz | `brcmfmac` | `sdio0`, alias `mmc0` |
| Bluetooth | the same module: BCM4345C5, Bluetooth 5.0 | `hci_uart` (`hci_bcm`) | `uart0` with RTS/CTS |
| PMIC | Rockchip RK808 | `rk808` | `i2c0` 0x1b |
| CPU and GPU supplies | Silergy SYR827 (big cores), SYR828 (GPU) | `fan53555` | `i2c0` 0x40, 0x41 |
| Battery | 10,000 mAh Li-ion; CW2015 fuel gauge | `cw2015_battery` | `i2c4` 0x62 |
| USB-C | FUSB302 controller: USB 3.0, power delivery in both directions, DisplayPort alt mode in hardware | `fusb302`, `tcpm` | `i2c4` 0x22 |
| DC jack | 5 V charger input | `gpio-charger` | `dc-charger` |
| Lid, power button | GPIO keys | `gpio-keys` | `gpio-key-lid`, `gpio-key-power` |
| LEDs | green (power), red (standby) | `leds-gpio` | `leds` |
| Serial console | UART2 on the headphone jack, after the switch on the mainboard is moved | `8250_dw` | `uart2`, `ttyS2` |

Ports: one USB-C, one USB 3.0 Type-A, one USB 2.0 Type-A, the DC jack, the
microSD slot and the headphone jack.

## CPU

| Cluster | Cores | Stock frequencies (device tree) | With the Pinebook app's overclock |
|---------|-------|---------------------------------|-----------------------------------|
| little | 4x Cortex-A53 | 408 to 1416 MHz | up to 1512 or 1608 MHz |
| big | 2x Cortex-A72 | 408 to 1800 MHz | up to 1992 or 2088 MHz |

The GPU runs from 200 to 800 MHz. The RK3399 is often quoted at 2.0 and
1.5 GHz; the Pinebook Pro's device tree stops at 1.8 and 1.416 GHz, and
going above that is what the overclock in the Pinebook app does.

## Disks and their names

The device tree's aliases fix the Linux names, whatever order the
controllers probe in. U-Boot numbers the same controllers differently:

| Disk | Linux | U-Boot |
|------|-------|--------|
| eMMC | `/dev/mmcblk2` | `mmc 0` |
| microSD | `/dev/mmcblk1` | `mmc 1` |
| NVMe | `/dev/nvme0n1` | `nvme 0` (after `pci enum; nvme scan`) |
| Wi-Fi (SDIO, not a disk) | `mmc0` | |

Partition `N` of a disk is `/dev/mmcblk1pN` or `/dev/nvme0n1pN`; ChromiumOS's
partition numbers and sizes are in [STORAGE.md](STORAGE.md).

## Boot order

The RK3399 boot ROM looks for a boot loader at sector 64 of the SPI flash,
then the eMMC, then the microSD card, and runs the first one it finds. It
cannot start from PCIe, so an NVMe SSD always needs a boot loader on one of
the others. How this port boots from each disk is in
[STORAGE_STRATEGY.md](STORAGE_STRATEGY.md).

## Audio routing

The ES8316's headphone output feeds both the headphone jack and the speaker
amplifier, whose enable line is a GPIO; inserting headphones is reported on
another GPIO, as the input device "rockchip,es8316-codec Headphones". The
UCM files in the board's BSP tell CRAS which mixer controls switch between
speaker, headphones and the internal microphone.

## Power

The battery is charged from the DC jack or from USB-C. The device tree lists
both as the fuel gauge's power supplies; the USB-C port asks a charger for
5 V and can also supply 5 V at 1.4 A to a device. The Pinebook app's *Питание*
page shows the power contract a USB-C charger negotiated.

## References

- [Pine64 wiki: Pinebook Pro](https://wiki.pine64.org/wiki/Pinebook_Pro):
  schematics, the mainboard switches, the serial console.
- [rk3399-pinebook-pro.dts in Linux 6.6](https://github.com/torvalds/linux/blob/v6.6/arch/arm64/boot/dts/rockchip/rk3399-pinebook-pro.dts).
