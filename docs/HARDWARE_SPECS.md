# PineBook Pro hardware specifications and revision notes

This document provides the hardware baseline for the ChromiumOS port and captures board revision details.

## PineBook Pro hardware baseline

### SoC and CPU
- **Processor**: Rockchip RK3399
- **Architecture**: ARMv8-A big.LITTLE
- **CPU cores**: 2x ARM Cortex-A72 (big) + 4x ARM Cortex-A53 (little)
- **Max frequency**: A72 @ 2.0 GHz, A53 @ 1.5 GHz
- **Cache**: L1 32KB/32KB (I/D per core), L2 1MB shared per cluster

### Memory
- **RAM**: 4GB LPDDR4 (every PineBook Pro ships with 4GB; there is no 8GB model)
- **Memory controller**: integrated in RK3399
- **Address map**: DRAM at `0x0`; RK3399 reserves the top 128MB of the 4GB window for MMIO, so about 3.875GB (`0x0`-`0xf8000000`) is usable

### GPU
- **GPU type**: Mali-T860 MP4 (quad-core)
- **GPU frequency**: typically 400-600 MHz
- **Display pipeline**: built-in HDMI, eDP, DSI support
- **Rendering**: OpenGL ES 3.1, Vulkan support

### Storage controllers

#### eMMC (internal)
- **Controller**: Arasan SDHCI (`&sdhci`, `mmc@fe330000`), driver `sdhci-of-arasan` (`CONFIG_MMC_SDHCI_OF_ARASAN`)
- **Module**: removable eMMC module, 64GB standard (128GB modules exist)
- **Speed**: HS200 (upstream device tree sets `mmc-hs200-1_8v`)
- **Device file**: `/dev/mmcblk2` (upstream alias `mmc2`)
- **Partitions**: typically boot + rootfs + stateful

#### microSD card slot
- **Controller**: Synopsys DesignWare MMC (`&sdmmc`, `mmc@fe320000`), driver `dw_mmc-rockchip` (`CONFIG_MMC_DW_ROCKCHIP`)
- **Protocol**: SD / UHS-I (upstream device tree enables SDR50)
- **Device file**: `/dev/mmcblk1` (upstream alias `mmc1`; `mmc0` is the SDIO Wi-Fi bus)
- **Supported capacities**: up to 1TB+ (SDXC compatible)

#### NVMe (optional upgrade)
- **Connection**: optional PINE64 M.2 adapter board (M-key NVMe SSD) on the internal PCIe connector
- **Controller**: RK3399 has a single PCIe 2.1 controller (`&pcie0`, up to x4 lanes); there is no second controller
- **Driver**: `pcie-rockchip-host` + `phy-rockchip-pcie` + `nvme`
- **Device file**: `/dev/nvme0n1`
- **Boot**: the RK3399 boot ROM cannot boot from PCIe, so U-Boot stays on SPI flash, eMMC or microSD and only the root filesystem lives on NVMe

### Input devices

#### Keyboard
- **Type**: 80-key mechanical keyboard with custom layout
- **Controller**: likely custom EC (embedded controller) or PS/2 compatible
- **Interface**: matrix-based or USB HID
- **Key layout**: Pinebook Pro specific, often with custom Linux key mappings

#### Touchpad
- **Type**: Synaptics RMI4 or compatible capacitive touchpad
- **Protocol**: I2C or PS/2
- **Bus**: usually I2C on Rockchip I2C pins
- **Driver**: `rmi_smbus` or `rmi_i2c` kernel modules

### Display

#### Internal panel
- **Resolution**: typically 1920x1080 (14-inch model)
- **Type**: IPS LCD panel
- **Interface**: eDP (Embedded DisplayPort) or MIPI DSI
- **Backlight**: PWM-controlled or PMIC-integrated
- **Panel controller**: usually Parade DisplayPort or Analogix DP
- **Device tree**: must include panel timings and backlight configuration

#### HDMI output
- **Type**: HDMI 2.0 or 1.4
- **Controller**: Rockchip HDMI PHY
- **Hot-plug detect**: supported

### Audio

#### Codec
- **Chipset**: Everest Semi ES8316 (I2C address 0x11)
- **Interface**: I2S1
- **Features**: headphone jack, internal speaker, microphone support
- **Driver**: `snd-soc-es8316` with `simple-audio-card` and `snd-soc-rockchip-i2s`

#### DAC/amplifier
- **Internal speaker**: usually powered by integrated amplifier
- **Headphone output**: 3.5mm jack with detection

### Wireless

#### Wi-Fi
- **Module**: AMPAK AP6256 (Broadcom BCM43456)
- **Standard**: IEEE 802.11ac, 2.4/5GHz
- **Interface**: SDIO (`&sdio0`)
- **Firmware**: `brcm/brcmfmac43456-sdio.bin`, `.clm_blob` and board NVRAM `brcmfmac43456-sdio.pine64,pinebook-pro.txt`
- **Driver**: `brcmfmac` (`CONFIG_BRCMFMAC`, `CONFIG_BRCMFMAC_SDIO`)
- **Device naming**: `wlan0`

#### Bluetooth
- **Chipset**: BCM4345C5, part of the AP6256 module
- **Standard**: Bluetooth 5.0
- **Interface**: UART0 with RTS/CTS (`brcm,bcm4345c5` node under `&uart0`)
- **Firmware**: `brcm/BCM4345C5.hcd`
- **Driver**: `hci_uart` with `hci_bcm` (`CONFIG_BT_HCIUART_BCM`, `CONFIG_SERIAL_DEV_BUS`)
- **Device naming**: `hci0`

### Power management

#### PMIC (Power Management IC)
- **Type**: Rockchip RK808D or similar
- **Responsibilities**: power rails, charging, sleep states
- **Interface**: I2C
- **Driver**: `rk808-regulator` and related subsystem drivers

#### Battery
- **Capacity**: typically 10,000-12,000 mAh
- **Chemistry**: Li-Po or similar
- **Charging**: via USB-C or dedicated charger port
- **Fuel gauge**: may use dedicated IC for battery status reporting

#### USB ports
- **Type-C port(s)**: typically 2x USB 3.0 Type-C
- **Controller**: Rockchip integrated USB 3.0 / 2.0 host
- **Features**: power delivery, video output (DP Alt Mode on some models)

### Cooling and thermal
- **Passive cooling**: aluminum chassis acts as heatsink
- **Thermal sensor**: typically integrated in PMIC or SoC
- **Throttling**: managed by thermal zones in kernel

## Board revisions

All PineBook Pro units share the same SoC, 4GB LPDDR4, ES8316 codec and AP6256 Wi-Fi/Bluetooth module. They differ in keyboard layout (ISO/ANSI) and in the eMMC module fitted (64GB standard, 128GB optional). One upstream device tree (`rk3399-pinebook-pro.dts`) covers all of them.

**Note**: Check your board's PCB silkscreen or CPU markings to determine exact revision.

## Storage controller mapping

For the ChromiumOS port, use these device paths. The numbering comes from the `mmc0`/`mmc1`/`mmc2` aliases in upstream `rk3399-pinebook-pro.dts` (`mmc0` is the SDIO Wi-Fi bus), so it does not depend on probe order:

```bash
# eMMC (internal)
/dev/mmcblk2      # full device
/dev/mmcblk2p1    # boot partition
/dev/mmcblk2p2    # kernel partition
/dev/mmcblk2p3    # rootfs partition

# microSD (removable)
/dev/mmcblk1      # full device
/dev/mmcblk1p1    # boot partition
/dev/mmcblk1p2    # kernel partition
/dev/mmcblk1p3    # rootfs partition

# NVMe (when using adapter)
/dev/nvme0n1      # full device
/dev/nvme0n1p1    # boot partition
/dev/nvme0n1p2    # kernel partition
/dev/nvme0n1p3    # rootfs partition
```

## Bootloader considerations

### U-Boot stages
1. **SPL (Secondary Program Loader)**: Rockchip `ddr_init` + minimal bootstrap
2. **TPL (Tertiary Program Loader)**: optional stage (RK3399 may skip)
3. **U-Boot main**: full bootloader with device enumeration

### Boot flow
- ROM code loads SPL from first 32KB of selected media
- SPL initializes DDR and jumps to U-Boot
- U-Boot loads kernel and device tree
- Kernel mounts rootfs from configured partition

## Kernel module dependencies

Essential modules for PineBook Pro boot:

```
- rockchip-pinctrl      # pin control
- rockchip-pmu          # power management unit
- rk3399-core           # CPU frequency scaling
- sdhci-of-arasan       # eMMC controller
- dw_mmc-rockchip       # microSD and SDIO controllers
- rk808-regulator       # PMIC regulator
- brcmfmac              # Wi-Fi (AP6256, SDIO)
- hci_uart              # Bluetooth (AP6256, UART, hci_bcm)
- rockchip-isp1         # image signal processor (optional)
- rockchip-dw-hdmi      # HDMI PHY
- analogix-dp           # DisplayPort (eDP)
- pwm-rockchip          # PWM for backlight
- rmi_smbus / rmi_i2c   # touchpad
- snd-soc-es8316        # audio codec
```

## Recommended hardware debugging

Before porting ChromiumOS:

1. Verify bootloader loads on your target media (eMMC first)
2. Confirm kernel boots with serial console output
3. Check `dmesg` for all hardware probe messages
4. Validate storage device enumeration
5. Test display output and backlight control
6. Confirm keyboard and touchpad input
7. Verify Wi-Fi/Bluetooth firmware load
8. Check battery and charging status
9. Test suspend/resume cycle

## Summary

PineBook Pro is a well-supported ARM64 board with modern hardware. The main porting challenges are:

- custom keyboard/touchpad mapping
- Wi-Fi firmware and driver setup
- audio codec initialization
- proper device tree for display timings
- thermal and power management tuning

A solid Linux baseline should validate most of these before ChromiumOS integration.
