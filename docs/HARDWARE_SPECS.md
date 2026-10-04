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
- **RAM**: DDR4 4GB (some models may have 8GB)
- **DDR frequency**: typically 800-1066 MHz depending on revision
- **Memory controller**: integrated in RK3399

### GPU
- **GPU type**: Mali-T860 MP4 (quad-core)
- **GPU frequency**: typically 400-600 MHz
- **Display pipeline**: built-in HDMI, eDP, DSI support
- **Rendering**: OpenGL ES 3.1, Vulkan support

### Storage controllers

#### eMMC (internal)
- **Controller**: Rockchip SDHCI host integrated in RK3399
- **Protocol**: eMMC 5.1 or later
- **Capacity**: typically 64GB or 128GB (varies by revision)
- **Speed**: HS200 or HS400 mode
- **Device file**: `/dev/mmcblk1` (when SD card is `mmcblk0`)
- **Partitions**: typically boot + rootfs + stateful

#### microSD card slot
- **Controller**: Rockchip SDHCI host (separate from eMMC)
- **Protocol**: SDIO / UHS-I or UHS-II
- **Device file**: `/dev/mmcblk0` (primary SD slot)
- **Speed**: depends on card class (UHS support for HS200 or better)
- **Supported capacities**: up to 1TB+ (SDXC compatible)

#### NVMe (optional upgrade)
- **Connection**: M.2 B-key slot or USB-C adapter
- **Protocol**: NVMe 1.3+
- **Controller path**: typically via USB 3.0 or direct PCIe
- **Device file**: `/dev/nvme0n1` (when USB-based) or direct (when native slot is used)
- **Speed**: PCIe 3.0 x4 theoretical maximum (~4GB/s)
- **Note**: Requires compatible M.2 SSD or USB adapter

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
- **Chipset**: typically Everest Semi ES8323 or similar
- **Interface**: I2S (Integrated Interchip Sound) bus
- **Features**: headphone jack, internal speaker, microphone support
- **Driver**: `rockchip_es8323` or similar SoC Rockchip audio driver

#### DAC/amplifier
- **Internal speaker**: usually powered by integrated amplifier
- **Headphone output**: 3.5mm jack with detection

### Wireless

#### Wi-Fi
- **Chipset**: Realtek RTL8723BS (typical for PineBook Pro)
- **Standard**: IEEE 802.11 b/g/n (or newer variants)
- **Interface**: SDIO (connected to secondary SD host)
- **Firmware**: requires binary firmware blob (`rtl8723bs_nic.bin`)
- **Driver**: `rtl8723bs` (Linux staging driver or vendor fork)
- **Device naming**: `wlan0`

#### Bluetooth
- **Chipset**: RTL8723BS includes BT
- **Standard**: Bluetooth 4.2 or 5.0 depending on firmware
- **Interface**: UART or USB (varies by RTL version)
- **Firmware**: `rtl8723b_fw.bin`
- **Driver**: `rtl8723bs_bt` or kernel BT stack
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

PineBook Pro has had multiple revisions. Key differences:

| Revision | Memory | Storage | Notable changes |
| --- | --- | --- | --- |
| v1.0 | 4GB DDR4 | 64GB eMMC | Initial release |
| v1.1 | 4GB DDR4 | 64GB or 128GB | Display improvements, minor tweaks |
| v1.2 | 4GB or 8GB | 64GB or 128GB | Better WiFi FW, panel tweaks |
| v2.0+ | 4GB or 8GB LPDDR4 | 128GB eMMC | Improved memory speed, stability |

**Note**: Check your board's PCB silkscreen or CPU markings to determine exact revision.

## Storage controller mapping

For the ChromiumOS port, use these device paths:

```bash
# eMMC (internal)
/dev/mmcblk1      # full device
/dev/mmcblk1p1    # boot partition
/dev/mmcblk1p2    # kernel partition
/dev/mmcblk1p3    # rootfs partition

# microSD (removable)
/dev/mmcblk0      # full device
/dev/mmcblk0p1    # boot partition
/dev/mmcblk0p2    # kernel partition
/dev/mmcblk0p3    # rootfs partition

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
- sdhci-of-dwcmshc      # SD card controller (alternative)
- rk808-regulator       # PMIC regulator
- rtl8723bs             # Wi-Fi/Bluetooth (SDIO)
- rockchip-isp1         # image signal processor (optional)
- rockchip-dw-hdmi      # HDMI PHY
- analogix-dp           # DisplayPort (eDP)
- pwm-rockchip          # PWM for backlight
- rmi_smbus / rmi_i2c   # touchpad
- rockchip-es8323       # audio codec
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
