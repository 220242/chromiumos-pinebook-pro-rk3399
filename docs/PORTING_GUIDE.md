# ChromiumOS board porting guide for PineBook Pro RK3399

This document outlines the step-by-step process to set up a ChromiumOS board definition and bring up the PineBook Pro RK3399 platform.

## Prerequisites

Before starting, you must have:

1. A Linux build machine (Ubuntu 20.04+ recommended)
2. ChromiumOS source tree and `cros_sdk` environment
3. A working PineBook Pro board (for testing)
4. Serial console access (USB-to-TTL adapter on UART pins)
5. Flashing tools: `dd`, `fastboot`, or ChromiumOS flash utilities
6. Reference kernel and U-Boot from Pine64 or Armbian

## Step 1: Verify board hardware and revision

**Goal**: Confirm exact hardware before porting.

### 1.1 Physical inspection

```bash
# Boot into any Linux distribution on your PineBook Pro
# Log in and check hardware details:

lsblk                           # storage devices
cat /proc/cpuinfo               # CPU and core info
free -h                         # memory
dmesg | grep -i rockchip        # SoC detection
cat /sys/class/dmi/id/product_name   # board model (if available)
```

### 1.2 Identify storage controllers

```bash
# Check device enumeration
lsblk -f                        # filesystems and block devices
cat /proc/partitions            # partition table
dmesg | grep -iE 'mmc|sd|nvme'  # storage subsystem messages

# For eMMC:
ls -la /dev/mmcblk1*            # should exist if eMMC is present

# For microSD:
ls -la /dev/mmcblk0*            # should exist when SD card is inserted

# For NVMe (if adapter plugged):
ls -la /dev/nvme*               # should exist if NVMe enumeration works
```

### 1.3 Document board revision

Record in your project notes:

- Board PCB revision (check silkscreen)
- CPU package marking (A72/A53 cluster information)
- Memory type (DDR4 or LPDDR4)
- eMMC capacity and speed class
- Wireless chipset (likely RTL8723BS)
- Display panel model (if identifiable)

**Example**: `PineBook Pro v1.2 | RK3399 | 4GB DDR4 | 128GB eMMC | RTL8723BS | 14" IPS panel`

## Step 2: Set up ChromiumOS build environment

**Goal**: Have a working `cros_sdk` and source tree.

### 2.1 Install ChromiumOS dependencies

```bash
sudo apt update
sudo apt install -y \
  build-essential python3 python-is-python3 \
  git curl wget ca-certificates \
  pkg-config libssl-dev uuid-dev \
  unzip zip rsync lsb-release \
  libcurses-ocaml-dev libncurses5-dev libncurses-dev \
  libc6-dev-arm64 g++-arm-linux-gnueabihf
```

### 2.2 Clone ChromiumOS manifest and source

```bash
mkdir -p ~/chromiumos
cd ~/chromiumos

# Initialize repo (Google's tool for managing multiple git repos)
curl https://storage.googleapis.com/git-repo-downloads/repo > repo
chmod +x repo
./repo init -u https://chromium.googlesource.com/chromiumos/manifest -b main

# This will prompt for your git configuration
./repo sync -j4    # sync all repositories (takes time and disk space)
```

### 2.3 Enter the ChromiumOS SDK

```bash
cd ~/chromiumos
# This will download and set up a containerized build environment
./cros_sdk --enter
```

You should now be inside the ChromiumOS SDK.

## Step 3: Create board definition

**Goal**: Add `pinebook-pro-rk3399` board to ChromiumOS.

### 3.1 Board directory structure

```bash
# Inside cros_sdk

BOARD_DIR="~/trunk/src/overlays/overlay-pinebook-pro-rk3399"
mkdir -p "${BOARD_DIR}"
cd "${BOARD_DIR}"

# Create the overlay structure
mkdir -p board-files/{firmware,kernel,dtb}
mkdir -p profiles/base
```

### 3.2 Create board configuration files

**File**: `~/trunk/src/overlays/overlay-pinebook-pro-rk3399/profiles/base/make.defaults`

```makefile
# ChromiumOS board make defaults for PineBook Pro RK3399
BOARD_OVERLAY := "overlay-pinebook-pro-rk3399"
BOARD_USE_NATIVE_CHROME := "yes"
BOARD_CAN_USE_FAST_MENUCONFIG := "yes"
DEFAULT_PROFILE_NAME := "base"

# Architecture
ARCH := "arm64"
KERNEL_ARCH := "arm64"

# Bootloader
EFIEFI := "0"
DEVELOPER_IMAGE := "1"
TEST_IMAGE := "1"
VM_IMAGE := "1"
```

**File**: `~/trunk/src/overlays/overlay-pinebook-pro-rk3399/make.conf`

```bash
# Additional board-specific make configuration
SIGN_IMAGES = "recovery kernel"
KERNEL_DEFCONFIG = "pinebook_pro_defconfig"
U_BOOT_DEFCONFIG = "pinebook-pro-rk3399"
```

### 3.3 Create board.conf for the project

Copy the board.conf from this repository to your overlay:

```bash
cp /path/to/this/repo/boards/pinebook-pro-rk3399/board.conf \
  "${BOARD_DIR}/board.conf"
```

## Step 4: Kernel configuration and device tree

**Goal**: Integrate Linux kernel with PineBook Pro support.

### 4.1 Download Pine64 or Armbian kernel sources

```bash
# Inside cros_sdk
cd ~/trunk/src/third_party/kernel

# Add remote for Pine64 kernel fork
git remote add pine64 https://github.com/pine64/linux.git
git fetch pine64

# Check out PineBook Pro branch
git checkout pine64/pinebook-pro    # or appropriate branch
```

### 4.2 Apply kernel config fragments

```bash
# Copy common config
cp /path/to/this/repo/boards/pinebook-pro-rk3399/kernel-config/common.config \
  kernel/arch/arm64/configs/pinebook_pro_common.config

# Copy storage-specific fragments
cp /path/to/this/repo/boards/pinebook-pro-rk3399/kernel-config/emmc.config \
  kernel/arch/arm64/configs/pinebook_pro_emmc.config
cp /path/to/this/repo/boards/pinebook-pro-rk3399/kernel-config/microsd.config \
  kernel/arch/arm64/configs/pinebook_pro_microsd.config
cp /path/to/this/repo/boards/pinebook-pro-rk3399/kernel-config/nvme.config \
  kernel/arch/arm64/configs/pinebook_pro_nvme.config
```

### 4.3 Device tree integration

Copy device tree overlays to kernel source:

```bash
cp /path/to/this/repo/boards/pinebook-pro-rk3399/overlays/*.dts \
  ~/trunk/src/third_party/kernel/arch/arm64/boot/dts/rockchip/
```

Edit the appropriate `.dts` file to match your exact board configuration:

```bash
# View and edit the eMMC device tree
vim ~/trunk/src/third_party/kernel/arch/arm64/boot/dts/rockchip/pinebook-pro-rk3399-emmc.dts
```

## Step 5: U-Boot bootloader setup

**Goal**: Configure U-Boot for PineBook Pro boot flow.

### 5.1 Clone U-Boot source

```bash
# Inside cros_sdk
cd ~/trunk/src/third_party/u-boot

# Add Pine64 U-Boot fork
git remote add pine64 https://github.com/pine64/u-boot.git
git fetch pine64
git checkout pine64/pinebook-pro  # or appropriate branch
```

### 5.2 Create or update U-Boot defconfig

```bash
# Check if PineBook Pro defconfig exists
grep -l "pinebook" u-boot/configs/*defconfig

# If not, copy and customize the RK3399 generic config
cp u-boot/configs/rockchip-rk3399-defconfig \
  u-boot/configs/pinebook-pro-rk3399-defconfig

# Edit the defconfig
vim u-boot/configs/pinebook-pro-rk3399-defconfig
```

**Key U-Boot options** to enable:

```
CONFIG_ARM64=y
CONFIG_ROCKCHIP=y
CONFIG_ROCKCHIP_RK3399=y
CONFIG_ROCKCHIP_SPL_BACK_TO_BROM=y
CONFIG_SYS_TEXT_BASE=0x02000000
CONFIG_MMC_SDHCI=y
CONFIG_MMC_SDHCI_ROCKCHIP=y
CONFIG_CMD_EXT4=y
CONFIG_CMD_FAT=y
CONFIG_PARTITION_TYPE_GUID=y
```

## Step 6: Firmware and binary blobs

**Goal**: Gather firmware needed for boot and hardware support.

### 6.1 Rockchip firmware (DDR, mini-loader)

Download from Rockchip RKBIN:

```bash
git clone https://github.com/rockchip-linux/rkbin.git ~/rkbin

# Copy needed binaries
cp ~/rkbin/bin/rk33/rk3399_ddr_800MHz_v1.26.bin \
  ~/chromiumos/src/overlays/overlay-pinebook-pro-rk3399/board-files/firmware/
cp ~/rkbin/bin/rk33/rk3399_miniloader_v1.26.bin \
  ~/chromiumos/src/overlays/overlay-pinebook-pro-rk3399/board-files/firmware/
```

### 6.2 Wireless firmware (Realtek RTL8723BS)

```bash
# Get Realtek firmware from official or community source
git clone https://github.com/morrissimo/rtl8723bs.git ~/rtl8723bs_src

# Firmware files (usually in firmware/ or similar)
cp ~/rtl8723bs_src/firmware/*.bin \
  ~/chromiumos/src/overlays/overlay-pinebook-pro-rk3399/board-files/firmware/
```

Expect at minimum:
- `rtl8723b_fw.bin` (Bluetooth firmware)
- `rtl8723bs_nic.bin` (Wi-Fi NIC firmware)

## Step 7: Build Linux baseline (pre-ChromiumOS)

**Goal**: Validate Linux boot before integrating ChromiumOS.

### 7.1 Build kernel

```bash
cd ~/trunk/src/third_party/kernel

# For eMMC target
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- pinebook_pro_emmc_defconfig
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc) Image
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc) dtbs

# Output:
# - arch/arm64/boot/Image
# - arch/arm64/boot/dts/rockchip/pinebook-pro-rk3399-emmc.dtb
```

### 7.2 Build U-Boot

```bash
cd ~/trunk/src/third_party/u-boot

make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- pinebook-pro-rk3399-defconfig
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc)

# Output:
# - u-boot.bin
# - u-boot-dtb.bin
```

## Step 8: Flash and test on hardware

**Goal**: Validate boot on your PineBook Pro board.

### 8.1 Prepare eMMC

```bash
# WARNING: This will overwrite your eMMC. Back up any data first!

# On your build machine:
BOARD_TARGET="/dev/sdX"  # Replace X with your eMMC/adapter device

# Write U-Boot to boot sector
sudo dd if=u-boot.bin of="${BOARD_TARGET}" seek=64 bs=512 conv=notrunc

# Write kernel at offset (example: 8192)
sudo dd if=arch/arm64/boot/Image of="${BOARD_TARGET}" seek=8192 bs=512 conv=notrunc

# Write device tree
sudo dd if=arch/arm64/boot/dts/rockchip/pinebook-pro-rk3399-emmc.dtb \
  of="${BOARD_TARGET}" seek=16384 bs=512 conv=notrunc
```

### 8.2 Boot and capture logs

```bash
# Connect serial console (USB-TTL adapter)
# Settings: 1500000 baud, 8N1

# Insert eMMC or SD card into PineBook Pro
# Power on and observe boot sequence

# Capture complete boot log:
screen /dev/ttyUSB0 1500000
# or
picocom -b 1500000 /dev/ttyUSB0
```

### 8.3 Verify key milestone messages

```
[typical boot sequence]
ROM code init...
SPL loads...
U-Boot main starts...
Loading kernel from....
Loading device tree...
Linux kernel boot message...
Rockchip platform init...
eMMC/SD controller init...
Storage devices detected: /dev/mmcblk1 (eMMC)
Keyboard and touchpad input...
[OK] System booted successfully
```

## Step 9: Integration into ChromiumOS build system

**Goal**: Connect the PineBook Pro board to ChromiumOS build flow.

### 9.1 Add board to ChromiumOS list

```bash
# Inside cros_sdk
ls ~/trunk/src/overlays/overlay-*/

# Your board overlay should appear in the list
ls ~/trunk/src/overlays/overlay-pinebook-pro-rk3399/
```

### 9.2 Build ChromiumOS image

```bash
# Inside cros_sdk
build_packages --board=pinebook-pro-rk3399
build_image --board=pinebook-pro-rk3399 --image_types=dev,recovery
```

### 9.3 Flash ChromiumOS to eMMC

```bash
# The build system generates ChromiumOS images
# Use cros flash utility or dd

TARGET_DEVICE="/dev/sdX"  # your eMMC or adapter
IMAGE_PATH="~/trunk/src/build/images/pinebook-pro-rk3399/latest/"

cros flash --board=pinebook-pro-rk3399 "${TARGET_DEVICE}" "${IMAGE_PATH}/recovery_image.bin"
```

## Step 10: Storage-specific builds and testing

**Goal**: Validate eMMC, microSD, and NVMe boot independently.

### 10.1 eMMC build

```bash
# Primary target - use the default configuration
build_image --board=pinebook-pro-rk3399 --image_types=dev,recovery
```

### 10.2 microSD build

```bash
# Create a microSD-specific overlay or board
# (May require creating overlay-pinebook-pro-rk3399-microsd)

build_image --board=pinebook-pro-rk3399-microsd --image_types=dev,recovery
```

### 10.3 NVMe build

```bash
# Create a NVMe-specific build
# (May require creating overlay-pinebook-pro-rk3399-nvme)

build_image --board=pinebook-pro-rk3399-nvme --image_types=dev,recovery
```

## Step 11: Hardware-specific tuning

**Goal**: Fix remaining hardware issues.

### 11.1 Display and backlight

Update device tree with exact panel timings:

```bash
vim ~/trunk/src/third_party/kernel/arch/arm64/boot/dts/rockchip/pinebook-pro-rk3399-common.dtsi

# Add or update panel node with correct timings from Armbian/Pine64 source
```

### 11.2 Audio codec configuration

Enable ES8323 audio codec in kernel and device tree.

### 11.3 Wi-Fi/Bluetooth setup

Load firmware and configure RTL8723BS drivers in kernel and rootfs.

## Step 12: Final validation checklist

Before considering the port "done":

- [ ] eMMC boot works reliably
- [ ] microSD boot works as fallback
- [ ] NVMe boot works (if targeting)
- [ ] Display shows ChromiumOS login screen
- [ ] Keyboard and touchpad input functional
- [ ] Wi-Fi/Bluetooth connect and scan
- [ ] Audio output works (speaker and headphone)
- [ ] Battery status displays correctly
- [ ] Suspend/resume cycle works
- [ ] Performance is acceptable
- [ ] No kernel panics or oops messages

## Summary

The PineBook Pro RK3399 ChromiumOS port is a multi-stage process:

1. Verify hardware and gather specs
2. Set up ChromiumOS SDK
3. Create board definition
4. Integrate kernel and U-Boot
5. Gather firmware and drivers
6. Build and test Linux baseline
7. Integrate into ChromiumOS build system
8. Flash and validate on hardware
9. Storage-specific testing (eMMC, microSD, NVMe)
10. Hardware tuning (display, audio, wireless, power)
11. Final validation and release

Each stage builds on the previous one. Don't skip to ChromiumOS integration until Linux baseline works.
