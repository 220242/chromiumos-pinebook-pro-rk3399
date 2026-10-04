# Critical drivers and firmware for PineBook Pro RK3399

This document lists all necessary Linux kernel drivers, firmware blobs, and platform support needed for a complete PineBook Pro port.

## Essential drivers (must-have)

### Platform and core
- `CONFIG_ARCH_ROCKCHIP` - Rockchip SoC platform support
- `CONFIG_ROCKCHIP_PM_DOMAINS` - power domain management
- `CONFIG_ROCKCHIP_IOMMU` - IOMMU support
- `CONFIG_PINCTRL_ROCKCHIP` - pin control (GPIO, multiplexing)
- `CONFIG_ROCKCHIP_TIMER` - timer support
- `CONFIG_CLK_ROCKCHIP` - clock management
- `CONFIG_REGULATOR_RK808` - PMIC regulator (RK808D)
- `CONFIG_RTC_DRV_RK808` - RTC from RK808 PMIC

### CPU and frequency scaling
- `CONFIG_CPUFREQ` - CPU frequency scaling framework
- `CONFIG_CPUFREQ_DT` - generic DT-based CPU freq driver
- `CONFIG_ARM_CPUFREQ_DT` - ARM CPU frequency scaling
- `CONFIG_ARM_DT_CPU_TOPOLOGY` - CPU topology from device tree
- `CONFIG_ARM_BIG_LITTLE_CPUFREQ` - big.LITTLE scheduler

### Memory and DDR
- `CONFIG_ARM64_VA_BITS_48` - 48-bit virtual addressing
- `CONFIG_ARM64_PA_BITS_48` - 48-bit physical addressing
- `CONFIG_SWIOTLB` - IOMMU bounce buffer support

### Storage (critical for three targets)

#### MMC/SD/eMMC
- `CONFIG_MMC` - MMC/SD card support
- `CONFIG_MMC_BLOCK` - block device for MMC
- `CONFIG_MMC_SDHCI` - SD Host Controller Interface
- `CONFIG_MMC_SDHCI_PLTFM` - platform SDHCI driver
- `CONFIG_MMC_SDHCI_OF_ARASAN` - Arasan SDHCI (for Rockchip)
- `CONFIG_MMC_SDHCI_OF_DWCMSHC` - Designware SDHCI (alternative)
- `CONFIG_MMC_SDHCI_ROCKCHIP` - Rockchip-specific SDHCI
- `CONFIG_MMC_DW` - Designware MMC controller
- `CONFIG_MMC_DW_ROCKCHIP` - Rockchip DW MMC
- `CONFIG_BLK_DEV_SD` - SCSI disk support (for SD/eMMC enumeration)

#### NVMe
- `CONFIG_NVME_CORE` - NVMe core protocol
- `CONFIG_BLK_DEV_NVME` - NVMe block device driver
- `CONFIG_NVME_FABRICS` - NVMe over Fabrics (optional)
- `CONFIG_NVME_MULTIPATH` - multipath I/O support
- `CONFIG_NVME_HWMON` - hardware monitoring for NVMe SSDs
- `CONFIG_PCI` - PCI bus support
- `CONFIG_PCI_MSI` - PCI message signaled interrupts
- `CONFIG_SCSI` - SCSI layer (for SD/SCSI-like interfaces)

### USB
- `CONFIG_USB` - USB support
- `CONFIG_USB_XHCI_HCD` - xHCI host controller
- `CONFIG_USB_XHCI_PLATFORM` - platform xHCI driver
- `CONFIG_USB_XHCI_TEGRA` - Tegra USB (if needed for some RK variants)
- `CONFIG_USB_STORAGE` - USB mass storage
- `CONFIG_USB_OHCI_HCD` - OHCI host controller (USB 1.1 fallback)
- `CONFIG_USB_EHCI_HCD` - EHCI host controller (USB 2.0)
- `CONFIG_USB_HID` - USB human interface devices

### Display and graphics
- `CONFIG_DRM` - Direct Rendering Manager
- `CONFIG_DRM_ROCKCHIP` - Rockchip DRM support
- `CONFIG_DRM_PANEL_SIMPLE` - simple panel driver
- `CONFIG_DRM_PANEL` - panel framework
- `CONFIG_DRM_HDMI` - HDMI support (if using HDMI output)
- `CONFIG_DRM_DP_HELPER` - DisplayPort helper (for eDP)
- `CONFIG_DRM_DW_HDMI` - Designware HDMI TX controller
- `CONFIG_DRM_ANALOGIX_DP` - Analogix DisplayPort controller (for eDP)
- `CONFIG_BACKLIGHT_PWM` - PWM-controlled backlight
- `CONFIG_BACKLIGHT_CLASS_DEVICE` - backlight class

### GPU
- `CONFIG_MALI_MIDGARD` - Mali GPU driver (may not be in kernel; often separate)
- `CONFIG_GPU_FREQ_SCALING` - GPU DVFS (optional)
- `CONFIG_DRM_ROCKCHIP_MALI` - Rockchip Mali integration (if available)

### Input devices
- `CONFIG_INPUT_EVDEV` - event device support
- `CONFIG_INPUT_KEYBOARD` - keyboard support
- `CONFIG_INPUT_MOUSE` - mouse/trackpad support
- `CONFIG_INPUT_TOUCHPAD` - touchpad support
- `CONFIG_SERIO` - serial I/O protocol
- `CONFIG_SERIO_I8042` - i8042 PS/2 keyboard/mouse controller (may be needed)
- `CONFIG_HID` - human interface device support
- `CONFIG_HID_GENERIC` - generic HID support
- `CONFIG_TOUCHSCREEN_SYNAPTICS_RMI4` - Synaptics RMI4 touchpad
- `CONFIG_RMI_SMBUS` - RMI4 over SMBus (I2C)
- `CONFIG_RMI_I2C` - RMI4 over I2C

### Audio
- `CONFIG_SND` - ALSA sound support
- `CONFIG_SND_SOC` - ALSA SoC (System-on-Chip) support
- `CONFIG_SND_SOC_ROCKCHIP` - Rockchip SoC audio
- `CONFIG_SND_SOC_ROCKCHIP_I2S` - Rockchip I2S controller
- `CONFIG_SND_SOC_ES8323` - Everest Semi ES8323 audio codec
- `CONFIG_SND_SOC_ES8328` - alternative codec variant
- `CONFIG_SND_SOC_SIMPLE_CARD` - simple card for audio routing
- `CONFIG_SND_SIMPLE_CARD_UTILS` - utilities for simple card

### Networking
- `CONFIG_NET` - networking support
- `CONFIG_INET` - TCP/IP
- `CONFIG_WIRELESS` - wireless support
- `CONFIG_CFG80211` - wireless configuration API
- `CONFIG_MAC80211` - MAC-level wireless stack

### Power management
- `CONFIG_PM` - power management framework
- `CONFIG_PM_SLEEP` - sleep mode support
- `CONFIG_SUSPEND` - suspend to RAM
- `CONFIG_HIBERNATION` - hibernation/suspend to disk (optional)
- `CONFIG_CPU_IDLE` - CPU idle states
- `CONFIG_CPU_IDLE_ROCKCHIP` - Rockchip idle driver
- `CONFIG_CPUIDLE_ARM_PSCI` - PSCI CPU idle (ARM standard)
- `CONFIG_CPUIDLE` - CPU idle framework
- `CONFIG_THERMAL` - thermal management
- `CONFIG_THERMAL_ROCKCHIP` - Rockchip thermal driver
- `CONFIG_THERMAL_OF` - thermal zones from device tree

### Temperature and monitoring
- `CONFIG_HWMON` - hardware monitoring framework
- `CONFIG_SENSORS_ROCKCHIP` - Rockchip temperature sensors
- `CONFIG_IIO` - Industrial I/O (may be needed for power/battery monitoring)

### Real-time and timekeeping
- `CONFIG_RTC_CLASS` - real-time clock support
- `CONFIG_RTC_DRV_RK808` - RK808 PMIC RTC
- `CONFIG_TIMEKEEPING_DEBUG` - timekeeping debugging (optional)

## Wireless drivers (RTL8723BS-specific)

### Wi-Fi
- `CONFIG_RTL8723BS` - Realtek 8723BS Wi-Fi driver (staging driver)
- `CONFIG_WLAN_VENDOR_REALTEK` - Realtek wireless vendor support
- `CONFIG_RTLWIFI` - Realtek Wi-Fi library
- Module: `rtl8723bs` or `rtl8723bs_sdio`

### Bluetooth
- `CONFIG_BT` - Bluetooth support
- `CONFIG_BT_RFCOMM` - RFCOMM protocol
- `CONFIG_BT_BNEP` - BNEP protocol (Bluetooth networking)
- `CONFIG_BT_HIDP` - HID over Bluetooth
- `CONFIG_BT_HCIUART` - UART HCI support
- `CONFIG_BT_HCIUART_BCSP` - BCSP protocol (if needed)
- `CONFIG_RTL_BTCOEX` - Realtek BT coexistence (optional)

## Firmware blobs (required files)

### Rockchip firmware (for bootloader)

**Location**: typically in U-Boot or bootloader stage

- `rk3399_ddr_*.bin` - DDR initialization firmware (multiple versions available)
- `rk3399_miniloader_*.bin` - mini-loader binary
- `rk3399_bl31_*.bin` - ARM trusted firmware (BL31 stage)

These are not Linux kernel firmware; they are bootloader/ROM code blobs.

### Wireless firmware (runtime)

**Location**: `/lib/firmware/` in rootfs

#### Realtek RTL8723BS
- `rtl8723b_fw.bin` - Bluetooth firmware blob
- `rtl8723bs_nic.bin` - Wi-Fi NIC firmware blob
- `rtl8723bs_wowlan.bin` - Wake-on-LAN firmware (optional)
- `rtl_bt/rtl8723b_config.bin` - Bluetooth configuration (optional)

### Panel and display firmware

Usually not needed for simple panels, but check device tree for any binary DRM firmware.

## Device tree requirements

Key device tree nodes that must be present and configured:

```
/
├── chosen
│   ├── bootargs (kernel command line)
│   └── stdout-path (serial console)
├── cpus
│   ├── cpu@0 (A53 cores)
│   └── cpu@100 (A72 cores)
├── memory@0
│   └── reg (DDR capacity and banks)
├── soc
│   ├── bus
│   ├── clock-controller
│   ├── pin-controller
│   ├── power-management
│   ├── pmu (CPU power unit)
│   ├── pwm (PWM controllers)
│   ├── i2c (I2C buses)
│   ├── uart (UART serial ports)
│   ├── gpio (GPIO controllers)
│   ├── sdhci (eMMC controller)
│   ├── sdmmc (SD card controller)
│   ├── usb (USB host/device)
│   ├── pcie (PCI-Express controller)
│   ├── drm (display controller)
│   ├── display-subsystem
│   ├── hdmi (HDMI PHY/controller)
│   ├── dp (DisplayPort/eDP controller)
│   ├── iommu (I/O memory management)
│   ├── i2c-regulators (PMIC I2C node)
│   └── sound (audio codec)
├── panel (display panel definition)
├── backlight (brightness control)
└── regulators (power rails)
```

## Build-time kernel config flags

**Recommended kernel config approach**:

```bash
# Base configuration
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- defconfig

# Apply common fragments
scripts/kconfig/merge_config.sh -m \
  .config \
  arch/arm64/configs/pinebook_pro_common.config \
  arch/arm64/configs/pinebook_pro_emmc.config

# For storage-specific builds, use the appropriate fragment:
# arch/arm64/configs/pinebook_pro_microsd.config
# arch/arm64/configs/pinebook_pro_nvme.config

# Build
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc)
```

## Testing driver presence

After boot, verify key drivers are loaded:

```bash
# Check loaded modules
lsmod | grep -iE 'rtl8723|mmc|nvme|drm|snd|usb'

# Check device tree expansion
ls /sys/devices/platform/ | grep -iE 'rockchip|rk3399'

# Check storage devices
ls -la /dev/mmcblk* /dev/nvme* 2>/dev/null

# Check display and input
ls -la /dev/input/
ls /sys/class/drm/

# Check audio
ls /proc/asound/
card_number=$(cat /proc/asound/cards | head -1 | awk '{print $1}')

# Check wireless
ls /sys/class/net/ | grep wlan
ifconfig wlan0  # should be present (may need to be brought up)
```

## Summary

A complete PineBook Pro port requires:

1. **Core platform drivers**: Rockchip SoC, PMIC, clocks, pinctrl
2. **Storage drivers**: MMC/SD (for eMMC + microSD), NVMe (optional), USB
3. **Display drivers**: DRM, panel, HDMI/eDP controllers, backlight
4. **Input drivers**: keyboard, touchpad (RMI4), USB HID
5. **Audio drivers**: I2S, SoC audio, ES8323 codec
6. **Wireless drivers**: RTL8723BS (Wi-Fi + Bluetooth)
7. **Power management**: CPUfreq, idle states, thermal, PMIC
8. **Firmware blobs**: Bootloader (Rockchip), wireless (Realtek)
9. **Device tree**: Complete board configuration with all nodes

This checklist ensures that a kernel image will boot successfully and support all hardware on the PineBook Pro.
