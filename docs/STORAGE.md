# Storage guide for PineBook Pro RK3399 ChromiumOS port

This document describes the three supported storage targets for the PineBook Pro board during the ChromiumOS porting process:

- internal eMMC
- microSD card
- NVMe drive

The goal is to keep the board port organized by storage type while validating boot, partitioning, and kernel support separately for each path.

## Supported storage targets

### 1. eMMC

Use case:
- default internal storage
- first boot target for a stable setup
- best fit for baseline testing

Checklist:
- verify boot offset and partition table
- confirm device-tree naming for the internal storage controller
- validate rootfs layout
- confirm read/write performance is acceptable
- verify suspend/resume behavior

### 2. microSD

Use case:
- recovery image testing
- easy swapping for experiments
- fallback boot media

Checklist:
- ensure U-Boot detects the SD card reliably
- validate kernel SD host controller support
- test large read/write operations
- verify rootfs partition behavior and boot selection

### 3. NVMe

Use case:
- high-performance storage path
- optional upgrade path for daily use

Checklist:
- confirm controller compatibility with kernel
- verify PCIe/NVMe enumeration in U-Boot and Linux
- test boot from NVMe
- validate rootfs partition layout and performance

## Recommended order

1. eMMC
2. microSD
3. NVMe

## Summary

The PineBook Pro RK3399 project should treat eMMC, microSD, and NVMe as separate validation targets. This keeps the ChromiumOS port manageable and makes it easier to isolate issues in bootloader, device tree, kernel modules, and partitioning.
