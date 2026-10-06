# ChromiumOS PineBook Pro RK3399 - Storage Strategy

## Boot and installation strategy

This project prioritizes **microSD as the primary boot and development target**, with documented paths for installing ChromiumOS to internal eMMC or NVMe storage.

### Why microSD as primary?

1. **Non-destructive**: SD card can be easily removed and replaced without affecting internal storage
2. **Development-friendly**: fast iteration - write image, test, swap card, repeat
3. **Recovery fallback**: if eMMC/NVMe boot fails, microSD always available as rescue media
4. **Hardware safety**: reduces risk of bricking internal storage during porting
5. **Testing flexibility**: can maintain multiple test images on different SD cards

## Boot hierarchy

```
1st priority: microSD (primary development and boot target)
   ↓ (successful boot, user wants internal storage)
2nd: Install from microSD → eMMC (system-to-system installation)
   ↓ (user wants NVMe upgrade)
3rd: Install from microSD → NVMe (system-to-system installation)
```

## Three workflow paths

### Path 1: Boot from microSD (primary development)

**Goal**: Validate ChromiumOS on microSD, test all hardware.

```bash
# Build ChromiumOS image for microSD
build_image --board=pinebook-pro-rk3399-microsd --image_types=dev,recovery

# Flash to microSD card
cros flash --board=pinebook-pro-rk3399-microsd /dev/sdX recovery_image.bin

# Insert microSD into PineBook Pro
# Power on and boot from card

# From booted ChromiumOS (microSD):
# - Validate display, keyboard, touchpad
# - Test Wi-Fi and Bluetooth
# - Check audio output
# - Verify battery and charging
# - Run performance benchmarks
```

### Path 2: Install from microSD to eMMC

**Goal**: Move running ChromiumOS from microSD card to internal eMMC storage.

**Prerequisites**:
- Booted ChromiumOS running from microSD
- eMMC is empty or you accept data loss
- Serial console or SSH access to running system

**Installation steps**:

```bash
# From microSD-booted ChromiumOS system:

# 1. Create partitions on eMMC
# List available block devices
lsblk
# Expected: /dev/mmcblk2 (eMMC), /dev/mmcblk1 (microSD running system)

# 2. Partition eMMC (example using parted)
sudo parted /dev/mmcblk2 mklabel gpt
sudo parted /dev/mmcblk2 mkpart boot fat32 2048s 264191s
sudo parted /dev/mmcblk2 mkpart kernel ext2 264192s 2361343s
sudo parted /dev/mmcblk2 mkpart rootfs ext4 2361344s 100%

# 3. Format partitions
sudo mkfs.fat -F32 /dev/mmcblk2p1
sudo mkfs.ext4 /dev/mmcblk2p3

# 4. Copy kernel and rootfs from microSD to eMMC
# Mount partitions
sudo mkdir -p /mnt/emmc-boot /mnt/emmc-rootfs
sudo mount /dev/mmcblk2p1 /mnt/emmc-boot
sudo mount /dev/mmcblk2p3 /mnt/emmc-rootfs

# Copy rootfs (running from microSD)
sudo rsync -avx / /mnt/emmc-rootfs/ --exclude={/dev,/proc,/sys,/tmp,/run,/mnt}

# 5. Update boot configuration on eMMC
# Modify /mnt/emmc-rootfs/etc/fstab to reference /dev/mmcblk2p3
sudo sed -i 's|/dev/mmcblk1|/dev/mmcblk2|g' /mnt/emmc-rootfs/etc/fstab

# 6. Write bootloader and kernel to eMMC
sudo dd if=/boot/u-boot.bin of=/dev/mmcblk2 bs=512 seek=64 conv=notrunc
sudo dd if=/boot/Image of=/dev/mmcblk2p2 bs=4096 conv=notrunc
sudo cp /boot/pinebook-pro-rk3399-emmc.dtb /mnt/emmc-boot/

# 7. Unmount and sync
sudo umount /mnt/emmc-boot /mnt/emmc-rootfs
sync

# 8. Power off, remove microSD, power on to test eMMC boot
sudo poweroff
```

**Validation after eMMC boot**:
- Verify system boots from eMMC
- Check storage device is `/dev/mmcblk2`
- Confirm no microSD dependency in rootfs
- Re-insert microSD and verify it mounts as secondary storage

### Path 3: Install from microSD to NVMe

**Goal**: Move running ChromiumOS from microSD to high-performance NVMe storage.

**Prerequisites**:
- Booted ChromiumOS running from microSD
- NVMe drive plugged in via adapter or native slot
- NVMe is empty or you accept data loss
- PCIe and NVMe drivers enabled in kernel

**Installation steps**:

```bash
# From microSD-booted ChromiumOS system:

# 1. Verify NVMe enumeration
lsblk
# Expected: /dev/nvme0n1 (if NVMe is detected)

# If not detected, check dmesg
dmesg | grep -iE 'nvme|pci'

# 2. Partition NVMe drive
sudo parted /dev/nvme0n1 mklabel gpt
sudo parted /dev/nvme0n1 mkpart boot fat32 2048s 264191s
sudo parted /dev/nvme0n1 mkpart kernel ext2 264192s 2361343s
sudo parted /dev/nvme0n1 mkpart rootfs ext4 2361344s 100%

# 3. Format NVMe partitions
sudo mkfs.fat -F32 /dev/nvme0n1p1
sudo mkfs.ext4 /dev/nvme0n1p3

# 4. Copy rootfs from microSD to NVMe
sudo mkdir -p /mnt/nvme-boot /mnt/nvme-rootfs
sudo mount /dev/nvme0n1p1 /mnt/nvme-boot
sudo mount /dev/nvme0n1p3 /mnt/nvme-rootfs

# Copy from running microSD system
sudo rsync -avx / /mnt/nvme-rootfs/ --exclude={/dev,/proc,/sys,/tmp,/run,/mnt}

# 5. Update boot configuration for NVMe
sudo sed -i 's|/dev/mmcblk|/dev/nvme0n1|g' /mnt/nvme-rootfs/etc/fstab

# 6. Write bootloader and kernel
sudo dd if=/boot/u-boot.bin of=/dev/nvme0n1 bs=512 seek=64 conv=notrunc
sudo dd if=/boot/Image of=/dev/nvme0n1p2 bs=4096 conv=notrunc
sudo cp /boot/pinebook-pro-rk3399-nvme.dtb /mnt/nvme-boot/

# 7. Update bootloader environment for NVMe
sudo fw_setenv root /dev/nvme0n1p3
sudo fw_setenv bootargs "console=ttyS2,1500000 root=/dev/nvme0n1p3 rw rootwait"

# 8. Unmount and sync
sudo umount /mnt/nvme-boot /mnt/nvme-rootfs
sync

# 9. Eject microSD, ensure NVMe is connected, power off and reboot
sudo poweroff
```

**Validation after NVMe boot**:
- Verify system boots from NVMe
- Check storage device is `/dev/nvme0n1`
- Monitor thermal and performance
- Verify microSD can still be inserted as secondary storage

## Build image variants

The project should generate three separate image variants:

### microSD image

**File**: `chromiumos-pinebook-pro-rk3399-microsd.img`

```bash
build_image --board=pinebook-pro-rk3399-microsd --image_types=dev,recovery
```

**Characteristics**:
- Boot arguments: `root=/dev/mmcblk1p3`
- Device tree: `pinebook-pro-rk3399-microsd.dtb`
- Kernel config: includes `microsd.config` fragment
- U-Boot optimized for SD card boot

### eMMC image (installable)

**File**: `chromiumos-pinebook-pro-rk3399-emmc-installable.img`

```bash
build_image --board=pinebook-pro-rk3399-emmc --image_types=dev,recovery
```

**Characteristics**:
- For flashing from running microSD system
- Boot arguments: `root=/dev/mmcblk2p3`
- Device tree: `pinebook-pro-rk3399-emmc.dtb`
- Kernel config: includes `emmc.config` fragment

### NVMe image (installable)

**File**: `chromiumos-pinebook-pro-rk3399-nvme-installable.img`

```bash
build_image --board=pinebook-pro-rk3399-nvme --image_types=dev,recovery
```

**Characteristics**:
- For flashing from running microSD system
- Boot arguments: `root=/dev/nvme0n1p3`
- Device tree: `pinebook-pro-rk3399-nvme.dtb`
- Kernel config: includes `nvme.config` fragment
- U-Boot with PCIe/NVMe support

## Installation script helpers

The project should include helper scripts:

**`scripts/install-to-emmc.sh`**
```bash
#!/bin/bash
# Installer for eMMC from microSD-booted system
# Usage: sudo ./install-to-emmc.sh
```

**`scripts/install-to-nvme.sh`**
```bash
#!/bin/bash
# Installer for NVMe from microSD-booted system
# Usage: sudo ./install-to-nvme.sh
```

**`scripts/backup-to-microsd.sh`**
```bash
#!/bin/bash
# Backup running system to microSD for recovery
# Usage: sudo ./backup-to-microsd.sh /dev/sdX
```

## Risk mitigation

Using microSD as primary target reduces risks:

| Risk | Mitigation |
| --- | --- |
| Bricked board | microSD always available as fallback |
| Lost data during install | eMMC/NVMe starts empty; microSD still bootable |
| Installation failure | Can reboot from microSD and try again |
| Driver bugs | Serial console debugging via USB-TTL |
| Firmware corruption | Reflash microSD image, system boots again |

## Recommended workflow for development

```
Week 1: Boot and validate from microSD
  → Test display, input, wireless, audio
  → Collect dmesg and kernel logs
  → Fix driver issues

Week 2-3: Stabilize microSD boot
  → Optimize kernel config
  → Validate suspend/resume
  → Test battery management
  → Ensure all hardware functional

Week 4: Test eMMC installation
  → Boot from microSD
  → Run install-to-emmc.sh
  → Validate eMMC boot
  → Test microSD as secondary storage

Week 5: Test NVMe installation
  → Boot from eMMC (or microSD)
  → Attach NVMe via adapter
  → Run install-to-nvme.sh
  → Validate NVMe boot performance
  → Benchmark vs eMMC and microSD

Week 6+: Final integration
  → ChromiumOS build system integration
  → Automated image generation
  → Release and documentation
```

## Summary

The PineBook Pro RK3399 ChromiumOS project uses **microSD as the primary development and boot target** because:

1. Safe and non-destructive
2. Enables fast iteration
3. Serves as permanent fallback
4. Reduces risk of hardware failure
5. Simplifies debugging and recovery

Once microSD boot is stable, users can transition to eMMC (internal) or NVMe (high-performance) using the provided installation paths.
