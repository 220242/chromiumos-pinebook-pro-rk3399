# Installation guide: eMMC and NVMe from microSD

This document provides detailed instructions for installing ChromiumOS from a microSD boot to internal eMMC or NVMe storage.

## Prerequisites

### General requirements
- ChromiumOS running from microSD card
- Serial console access (optional but recommended)
- SSH access to running system (or direct terminal)
- Target storage (eMMC or NVMe) with no important data

### For eMMC installation
- Internal eMMC recognized in `lsblk` as `/dev/mmcblk1`
- At least 32GB eMMC capacity
- Proper eMMC controller driver support

### For NVMe installation
- NVMe drive plugged into M.2 slot or USB adapter
- Recognized in `lsblk` as `/dev/nvme0n1`
- PCIe/NVMe kernel support enabled
- At least 32GB NVMe capacity

## Installation to eMMC

### Step 1: Boot from microSD and prepare

```bash
# Boot ChromiumOS from microSD card
# Log in via SSH or direct terminal

# Verify storage devices
lsblk
# Output should show:
# mmcblk0     (microSD - currently running system)
# mmcblk1     (eMMC - target for installation)
# mmcblk0p1, mmcblk0p2, mmcblk0p3  (microSD partitions)

# Check eMMC is empty/safe to wipe
sudo fdisk -l /dev/mmcblk1
# Note the total capacity

# Open root shell for installation
sudo -s
```

### Step 2: Partition eMMC

```bash
# WARNING: This will erase /dev/mmcblk1
# Double-check you have the correct device before proceeding

# Clear any existing partition table
sudo dd if=/dev/zero of=/dev/mmcblk1 bs=512 count=2048

# Create GPT partition table
sudo parted -s /dev/mmcblk1 mklabel gpt

# Create three partitions:
# 1. Boot partition (FAT32, 256MB)
sudo parted -s /dev/mmcblk1 mkpart boot fat32 2048s 264191s

# 2. Kernel partition (ext2, 2GB)
sudo parted -s /dev/mmcblk1 mkpart kernel ext2 264192s 2361343s

# 3. Rootfs partition (ext4, remaining space)
sudo parted -s /dev/mmcblk1 mkpart rootfs ext4 2361344s 100%

# Verify partitions were created
sudo fdisk -l /dev/mmcblk1
```

### Step 3: Format partitions

```bash
# Format boot partition (FAT32)
sudo mkfs.fat -F32 /dev/mmcblk1p1

# Format rootfs partition (ext4)
sudo mkfs.ext4 -F -L "chromeos-rootfs" /dev/mmcblk1p3

# Verify filesystems
sudo blkid | grep mmcblk1
```

### Step 4: Copy rootfs from microSD to eMMC

```bash
# Create mount points
sudo mkdir -p /mnt/emmc-boot /mnt/emmc-rootfs

# Mount eMMC partitions
sudo mount /dev/mmcblk1p1 /mnt/emmc-boot
sudo mount /dev/mmcblk1p3 /mnt/emmc-rootfs

# Copy entire rootfs from microSD to eMMC
# This preserves all ChromiumOS system files
echo "Copying rootfs... (this may take 10-30 minutes)"
sudo rsync -avx \
  --exclude=/dev \
  --exclude=/proc \
  --exclude=/sys \
  --exclude=/tmp \
  --exclude=/run \
  --exclude=/mnt \
  --exclude=/media \
  --exclude=/lost+found \
  / /mnt/emmc-rootfs/

# Verify copy completed successfully
echo "Verifying rootfs..."
ls -la /mnt/emmc-rootfs/bin /mnt/emmc-rootfs/boot /mnt/emmc-rootfs/etc
```

### Step 5: Update fstab for eMMC boot

```bash
# Edit fstab to point to eMMC device
sudo sed -i 's|/dev/mmcblk0|/dev/mmcblk1|g' /mnt/emmc-rootfs/etc/fstab

# Verify changes
echo "Updated fstab:"
sudo grep mmcblk /mnt/emmc-rootfs/etc/fstab

# Should show mmcblk1 (not mmcblk0)
```

### Step 6: Copy bootloader and kernel

```bash
# Copy kernel image to kernel partition
sudo cp /boot/Image /mnt/emmc-rootfs/boot/Image-emmc

# Copy device tree for eMMC boot
sudo cp /boot/dts/pinebook-pro-rk3399-emmc.dtb /mnt/emmc-boot/
sudo cp /boot/dts/pinebook-pro-rk3399-emmc.dtb /mnt/emmc-rootfs/boot/

# Update bootloader environment for eMMC
# (if fw_setenv is available)
if command -v fw_setenv >/dev/null; then
    sudo fw_setenv root /dev/mmcblk1p3
    sudo fw_setenv bootargs "console=ttyS2,1500000 root=/dev/mmcblk1p3 rw rootwait"
fi

# Verify files in place
ls -la /mnt/emmc-boot/
ls -la /mnt/emmc-rootfs/boot/
```

### Step 7: Finalize and unmount

```bash
# Sync all data to disk
sync
sleep 2

# Unmount eMMC partitions
sudo umount /mnt/emmc-boot /mnt/emmc-rootfs

# Verify unmounted
df -h | grep mnt
# Should show no mnt entries

echo "eMMC installation complete"
```

### Step 8: Boot from eMMC

```bash
# Power off the system
sudo poweroff

# Wait for system to shut down (watch serial console)
# Remove microSD card (optional but recommended)
# Power on the PineBook Pro

# System should now boot from eMMC
# If it doesn't:
#   - Insert microSD to recover
#   - Check serial console for boot errors
#   - Verify bootloader configuration
```

### Step 9: Verify eMMC boot

```bash
# After eMMC boots successfully, verify storage device
lsblk
# Should show mmcblk1 as root device (not mmcblk0)

# Check mount points
df -h
# Root (/) should be on /dev/mmcblk1p3

# Verify microSD functionality (optional)
# Insert microSD card and check it mounts as secondary storage
lsblk
# Should show both mmcblk0 (microSD) and mmcblk1 (eMMC)
```

## Installation to NVMe

### Step 1: Boot from microSD/eMMC and verify NVMe

```bash
# Boot from microSD or eMMC
# Plug in NVMe drive via adapter or direct slot
# Wait 5 seconds for PCIe enumeration

# Verify NVMe is detected
lsblk
# Should show nvme0n1 device

# If not detected, check kernel log
dmesg | tail -50 | grep -iE 'nvme|pci|error'

# If still not detected, NVMe driver may need to be loaded
modprobe nvme
modprobe nvme_core
lsblk  # try again
```

### Step 2: Partition NVMe

```bash
# Open root shell
sudo -s

# Clear existing partition table
sudo dd if=/dev/zero of=/dev/nvme0n1 bs=512 count=2048

# Create GPT partition table
sudo parted -s /dev/nvme0n1 mklabel gpt

# Create three partitions
# 1. Boot partition (FAT32, 256MB)
sudo parted -s /dev/nvme0n1 mkpart boot fat32 2048s 264191s

# 2. Kernel partition (ext2, 2GB)
sudo parted -s /dev/nvme0n1 mkpart kernel ext2 264192s 2361343s

# 3. Rootfs partition (ext4, remaining space)
sudo parted -s /dev/nvme0n1 mkpart rootfs ext4 2361344s 100%

# Verify partitions
sudo fdisk -l /dev/nvme0n1
```

### Step 3: Format NVMe partitions

```bash
# Format boot partition
sudo mkfs.fat -F32 /dev/nvme0n1p1

# Format rootfs partition
sudo mkfs.ext4 -F -L "chromeos-nvme" /dev/nvme0n1p3

# Verify
sudo blkid | grep nvme0n1
```

### Step 4: Copy rootfs to NVMe

```bash
# Create mount points
sudo mkdir -p /mnt/nvme-boot /mnt/nvme-rootfs

# Mount NVMe partitions
sudo mount /dev/nvme0n1p1 /mnt/nvme-boot
sudo mount /dev/nvme0n1p3 /mnt/nvme-rootfs

# Copy rootfs from current boot device
echo "Copying rootfs to NVMe... (this may take 15-45 minutes)"
sudo rsync -avx \
  --exclude=/dev \
  --exclude=/proc \
  --exclude=/sys \
  --exclude=/tmp \
  --exclude=/run \
  --exclude=/mnt \
  --exclude=/media \
  --exclude=/lost+found \
  / /mnt/nvme-rootfs/

# Verify copy
ls -la /mnt/nvme-rootfs/bin /mnt/nvme-rootfs/boot /mnt/nvme-rootfs/etc
```

### Step 5: Update configuration for NVMe

```bash
# Update fstab
sudo sed -i 's|/dev/mmcblk|/dev/nvme0n1|g' /mnt/nvme-rootfs/etc/fstab
sudo sed -i 's|/dev/sda|/dev/nvme0n1|g' /mnt/nvme-rootfs/etc/fstab

# Verify
sudo grep nvme0n1 /mnt/nvme-rootfs/etc/fstab

# Copy kernel and device tree
sudo cp /boot/Image /mnt/nvme-rootfs/boot/Image-nvme
sudo cp /boot/dts/pinebook-pro-rk3399-nvme.dtb /mnt/nvme-boot/
sudo cp /boot/dts/pinebook-pro-rk3399-nvme.dtb /mnt/nvme-rootfs/boot/

# Update U-Boot environment for NVMe boot
if command -v fw_setenv >/dev/null; then
    sudo fw_setenv root /dev/nvme0n1p3
    sudo fw_setenv bootargs "console=ttyS2,1500000 root=/dev/nvme0n1p3 rw rootwait"
fi
```

### Step 6: Finalize and unmount

```bash
# Sync all data
sync
sleep 2

# Unmount NVMe
sudo umount /mnt/nvme-boot /mnt/nvme-rootfs

# Verify
df -h | grep mnt

echo "NVMe installation complete"
```

### Step 7: Boot from NVMe

```bash
# Power off
sudo poweroff

# Wait for shutdown
# Remove microSD if installed
# Ensure NVMe is firmly connected
# Power on

# System should boot from NVMe
# Monitor serial console for any errors
```

### Step 8: Verify NVMe boot

```bash
# After successful boot from NVMe:
lsblk
# Should show nvme0n1 as root device

df -h
# Root (/) should be /dev/nvme0n1p3

# Check performance improvement over eMMC
# (optional benchmark)
hdparm -Tt /dev/nvme0n1
hdparm -Tt /dev/mmcblk1  # compare with eMMC if available
```

## Troubleshooting

### Installation fails with "Permission denied"

```bash
# Run installer with sudo or as root
sudo bash
# or
sudo -s
```

### Target device not found

```bash
# Verify device exists
lsblk
ls -la /dev/mmcblk1 /dev/nvme0n1

# Check dmesg for controller errors
dmesg | grep -iE 'error|fail|controller'
```

### Installation slow or hangs

```bash
# rsync may take 30+ minutes on slow eMMC/SD
# Monitor progress:
watch -n 5 'du -sh /mnt/emmc-rootfs'  # in separate terminal

# If process seems hung, check I/O
iostat -x 1
```

### Boot fails after installation

```bash
# Boot from microSD recovery
# Check serial console logs
# Verify fstab is correct
# Verify device tree is correct
# Try flashing U-Boot again

sudo dd if=/usr/lib/u-boot/pinebook-pro/u-boot.bin \
  of=/dev/mmcblk1 bs=512 seek=64 conv=notrunc
```

### NVMe not detected

```bash
# Load NVMe drivers
sudo modprobe nvme
sudo modprobe nvme_core

# Check kernel messages
dmesg | grep -iE 'nvme|pci|slot'

# If still not detected, check PCIe enumeration
lspci
# NVMe should appear as "Mass storage controller"
```

## Summary

The installation process is straightforward:

1. Boot from microSD
2. Partition target (eMMC or NVMe)
3. Copy rootfs via rsync
4. Update configuration files
5. Copy bootloader and device tree
6. Reboot and validate

Each step should take 5-60 minutes depending on storage speed. If any step fails, you can always reboot from microSD and try again.
