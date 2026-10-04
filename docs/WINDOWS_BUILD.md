# ChromiumOS PineBook Pro RK3399 — Windows 11 + WSL build guide

This document describes building ChromiumOS for PineBook Pro (RK3399) on Windows 11 using WSL2, PowerShell, and the same pattern as the `android_manifest` Khadas Edge1 project.

## Prerequisites

### Windows 11 setup

1. **WSL2 with Ubuntu 22.04 LTS**
   ```powershell
   wsl --install Ubuntu-22.04
   wsl --set-default-version 2
   ```

2. **Disk layout**: D:\ for build (at least 400GB free)
   ```powershell
   # Example structure:
   # D:\chromiumos\          (main project root)
   # D:\chromiumos\repo\     (ChromiumOS source via repo tool)
   # D:\chromiumos\output\   (build artifacts and logs)
   # D:\chromiumos\logs\     (build logs)
   ```

3. **PowerShell 7.4+**
   ```powershell
   # Run PowerShell as Administrator
   winget install Microsoft.PowerShell
   pwsh --version
   ```

4. **Git for Windows**
   ```powershell
   winget install Git.Git
   git --version
   ```

## Project structure

Following android_manifest pattern:

```
D:\chromiumos\
├── android_manifest\         (or chromiumos_manifest - this repo)
│   ├── build\
│   │   ├── linux\            (main build scripts)
│   │   ├── windows\          (WSL2 orchestrator)
│   │   ├── lib-tree.sh       (tree utilities)
│   │   └── log-*.sh          (logging utilities)
│   ├── docs\
│   ├── boards\
│   ├── overlays\
│   └── README.md
├── repo\                     (ChromiumOS source via `repo` tool)
│   ├── .repo\
│   ├── chromiumos\
│   ├── third_party\kernel\
│   ├── third_party\u-boot\
│   └── ...
└── output\                   (symlink or actual directory)
    ├── images\               (final .img.gz files)
    ├── logs\                 (detailed build logs)
    └── intermediate\         (kernel, U-Boot, rootfs)
```

## Build workflow

### From Windows (PowerShell)

The main entry point is a PowerShell script that orchestrates the entire build through WSL2.

**File**: `build/windows/Start-PinebookBuild.ps1`

```powershell
# Run from Windows PowerShell 7 (pwsh)
cd D:\chromiumos
pwsh -ExecutionPolicy Bypass -File .\android_manifest\build\windows\Start-PinebookBuild.ps1
```

This script:
1. Checks disk space and prerequisites
2. Mounts D:\ in WSL2 as `/mnt/d`
3. Enters WSL2 environment
4. Runs build sequence with logging
5. Copies artifacts back to Windows

### From WSL2 (Linux)

Inside WSL2, the build follows standard ChromiumOS flow:

```bash
# Inside WSL2:
cd /mnt/d/chromiumos

# Run build steps (see details below)
build/verify-tree.sh
build/preflight.sh
build/sync.sh
build/build-kernel.sh
build/build-uboot.sh
build/build.sh userdebug
build/build-images.sh
```

## Setup and initialization

### Step 1: Prepare Windows directories

```powershell
# Run as Administrator in PowerShell 7

# Create base directory on D:
New-Item -ItemType Directory -Path "D:\chromiumos" -Force
Set-Location "D:\chromiumos"

# Create subdirectories
New-Item -ItemType Directory -Path "D:\chromiumos\output\logs" -Force
New-Item -ItemType Directory -Path "D:\chromiumos\output\images" -Force

# Clone this repository
git clone https://github.com/220242/chromiumos-pinebook-pro-rk3399.git `
  D:\chromiumos\android_manifest

# Verify clone
ls D:\chromiumos\android_manifest\build
```

### Step 2: Initialize WSL2 environment

```powershell
# In PowerShell 7

# Start WSL2
wsl -d Ubuntu-22.04

# Inside WSL2:
cd /mnt/d/chromiumos

# Run preflight check
bash android_manifest/build/preflight.sh

# This checks:
# - Disk space (400GB minimum for full build)
# - Available RAM (16GB+ recommended)
# - CPU cores (8+ for parallel build)
# - Git and repo tool access
# - ChromiumOS build dependencies
```

### Step 3: Clone ChromiumOS repository

```bash
# Inside WSL2:
cd /mnt/d/chromiumos

# Install repo tool
curl https://storage.googleapis.com/git-repo-downloads/repo > repo
chmod +x repo
sudo mv repo /usr/local/bin/

# Initialize ChromiumOS manifest
repo init -u https://chromium.googlesource.com/chromiumos/manifest -b main

# Sync repositories (takes 30-60 minutes on first run)
repo sync -j4

# This creates:
# - .repo/             (repo metadata)
# - chromiumos/        (platform code)
# - third_party/       (kernel, U-Boot, etc.)
```

## Build scripts

Each script logs to `output/logs/` and supports the same pattern as android_manifest:

### `build/verify-tree.sh`

```bash
# Static checks without needing AOSP/ChromiumOS source
build/verify-tree.sh

# Checks:
# - Device tree files present
# - Build configuration valid
# - Kernel config fragments syntactically correct
# - U-Boot defconfig valid
```

### `build/preflight.sh`

```bash
# Verify system is ready to build
build/preflight.sh

# Checks:
# - Disk: 400GB free
# - RAM: 16GB+ available
# - CPU: 8+ cores
# - Tools: git, curl, python3, build-essential
# - Network: can reach chromium.googlesource.com
```

### `build/sync.sh`

```bash
# Fetch ChromiumOS source and manifests
build/sync.sh [tree-root]

# Optional argument:
# If no tree-root given, looks for ~/chromiumos or ~/aosp
# Downloads ~120GB of source
# Sets up local_manifest for PineBook Pro

# Creates:
# - chromiumos/platform/
# - third_party/kernel/
# - third_party/u-boot/
```

### `build/build-kernel.sh`

```bash
# Build Linux kernel with ChromiumOS + PineBook Pro config
build/build-kernel.sh [tree-root]

# Builds:
# - arch/arm64/boot/Image
# - arch/arm64/boot/dts/rockchip/pinebook-pro-rk3399-*.dtb
# - kernel modules

# Uses kernel config from:
# - boards/pinebook-pro-rk3399/kernel-config/common.config
# - boards/pinebook-pro-rk3399/kernel-config/{emmc,microsd,nvme}.config
```

### `build/build-uboot.sh`

```bash
# Build U-Boot bootloader
build/build-uboot.sh [tree-root]

# Builds:
# - u-boot.bin
# - u-boot-dtb.bin
# - MLO (if applicable)

# Uses U-Boot config from:
# - boards/pinebook-pro-rk3399/board.conf
# - Pine64 U-Boot fork (https://github.com/pine64/u-boot)
```

### `build/build.sh`

```bash
# Main ChromiumOS build
build/build.sh userdebug [tree-root]

# Arguments:
# - Target: userdebug, release, etc.
# - Optional tree-root

# Builds:
# - ChromiumOS base system
# - All required binaries
# - Recovery image components

# Output: out/board_name/
```

### `build/build-images.sh`

```bash
# Generate complete disk images
build/build-images.sh [tree-root]

# Creates three images:
# - chromiumos-pinebook-pro-microsd.img.gz   (primary boot target)
# - chromiumos-pinebook-pro-emmc.img.gz      (for installation to eMMC)
# - chromiumos-pinebook-pro-nvme.img.gz      (for installation to NVMe)

# Each image contains:
# - Bootloader (U-Boot)
# - Device tree
# - Kernel
# - Ramdisk
# - Root filesystem
# - Boot script

# Outputs to: output/images/
```

## Logging and diagnostics

All build scripts automatically log to `output/logs/`:

```
output/logs/
├── verify-tree-2026-10-04-063245.log
├── preflight-2026-10-04-063250.log
├── sync-2026-10-04-063300.log        (long: 30+ minutes)
├── build-kernel-2026-10-04-065000.log (long: 15-30 minutes)
├── build-uboot-2026-10-04-065500.log
├── build-2026-10-04-070000.log        (long: 20-60 minutes)
└── build-images-2026-10-04-080000.log
```

**Example log entry**:
```
2026-10-04 06:30:00 [INFO] Starting kernel build
2026-10-04 06:30:05 [CMD] make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j8
2026-10-04 06:45:30 [INFO] Kernel Image ready at arch/arm64/boot/Image
2026-10-04 06:46:00 [INFO] Device trees built
2026-10-04 06:46:15 [SUCCESS] Kernel build complete (900s)
```

### View logs in real-time

```powershell
# From Windows PowerShell
wsl tail -f /mnt/d/chromiumos/output/logs/build-kernel-*.log

# Or directly in Windows
Get-Content D:\chromiumos\output\logs\build-kernel-*.log -Wait
```

## Typical build sequence

### Initial setup (one-time)

```powershell
# PowerShell 7 on Windows 11
cd D:\chromiumos

# Clone this repository
git clone https://github.com/220242/chromiumos-pinebook-pro-rk3399.git `
  android_manifest

# Enter WSL2
wsl -d Ubuntu-22.04
```

```bash
# Inside WSL2:
cd /mnt/d/chromiumos

# Preflight check
bash android_manifest/build/preflight.sh

# Sync ChromiumOS source
bash android_manifest/build/sync.sh
# Takes 30-60 minutes
```

### Build cycle (iterative)

```bash
# Inside WSL2:
cd /mnt/d/chromiumos

# After syncing, build in order:
bash android_manifest/build/verify-tree.sh
bash android_manifest/build/build-kernel.sh
bash android_manifest/build/build-uboot.sh
bash android_manifest/build/build.sh userdebug
bash android_manifest/build/build-images.sh

# Total time: ~1.5-2 hours on a decent machine
```

### Quick rebuild (after code changes)

```bash
# If only kernel config changed:
bash android_manifest/build/build-kernel.sh
bash android_manifest/build/build-images.sh

# If only U-Boot changed:
bash android_manifest/build/build-uboot.sh
bash android_manifest/build/build-images.sh

# If only rootfs changed:
bash android_manifest/build/build.sh userdebug
bash android_manifest/build/build-images.sh
```

## Output artifacts

After successful build:

```
output/images/
├── chromiumos-pinebook-pro-microsd.img.gz      (512MB - 2GB)
├── chromiumos-pinebook-pro-emmc.img.gz         (same)
├── chromiumos-pinebook-pro-nvme.img.gz         (same)
├── SHA256SUMS                                   (checksums)
└── MANIFEST.txt                                 (build metadata)

output/intermediate/
├── kernel/                                      (Image, dtbs)
├── uboot/                                       (u-boot.bin)
└── rootfs/                                      (unpacked system)
```

## Flashing to storage media

### Windows: Using Balena Etcher

1. Download Balena Etcher: https://www.balena.io/etcher/
2. Insert microSD card
3. Open Etcher
4. Select `chromiumos-pinebook-pro-microsd.img.gz` from `D:\chromiumos\output\images\`
5. Select microSD target
6. Click "Flash"

### Linux/WSL2: Using dd

```bash
# Inside WSL2 (must have direct access to /dev/sdX)

# List devices
lsblk

# Decompress and write
gunzip -c output/images/chromiumos-pinebook-pro-microsd.img.gz | \
  sudo dd of=/dev/sdX bs=4M status=progress

sync
```

### From running ChromiumOS (microSD to eMMC/NVMe)

Once you boot the microSD image, use the installation scripts:

```bash
# From ChromiumOS running on microSD:
adb root
adb shell sh /vendor/bin/install-to-emmc.sh    # → eMMC
adb shell sh /vendor/bin/install-to-nvme.sh    # → NVMe
```

## Integration with Android container

ChromiumOS includes Chrome with integrated Android container. Build notes:

1. **ARC++ (Android Runtime for Chrome)** is built into ChromiumOS
2. Android apps run in containerized environment
3. Shared kernel (6.12+), separate rootfs
4. Hardware acceleration through DRM/Mesa

For PineBook Pro:
- Mali GPU supported through `libGLES_mesa` (panfrost)
- Audio passthrough to ALSA
- Wi-Fi/Bluetooth through host drivers
- Storage access through /data partition

## Troubleshooting

### WSL2 integration issues

```powershell
# Check WSL2 is running
wsl --list --verbose

# Restart WSL2
wsl --terminate Ubuntu-22.04
wsl -d Ubuntu-22.04

# Check D: mounting
wsl mount | grep /mnt/d
```

### Build failures

```bash
# Check latest log
tail -100 output/logs/build-*.log

# Re-run specific step with verbose output
build/build-kernel.sh --verbose

# Clean and retry
rm -rf out/
build/build.sh userdebug
```

### Out of disk space

```bash
# Check usage
df -h /mnt/d

# Clean build artifacts
rm -rf out/ && sync

# Remove intermediate files
rm -rf third_party/kernel/out third_party/u-boot/out
```

## Summary

The PineBook Pro RK3399 ChromiumOS build system:

1. **Runs on Windows 11 + WSL2** through PowerShell orchestration
2. **Uses disk D:\** for all build artifacts
3. **Follows android_manifest pattern** for consistency
4. **Generates three image variants**: microSD (primary), eMMC (internal), NVMe (upgrade)
5. **Includes integrated logging** for diagnostics
6. **Supports iterative development** with quick rebuild paths
7. **Integrates Android** through ARC++ container

Total build time: 1.5-2 hours on a modern machine with 8+ cores and 16GB+ RAM.
