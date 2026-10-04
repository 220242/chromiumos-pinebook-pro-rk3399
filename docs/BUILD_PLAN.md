# PineBook Pro RK3399 build plan

This file captures the practical plan for a ChromiumOS board port on PineBook Pro using Rockchip RK3399.

## Goal

Produce a reproducible path to compile and flash ChromiumOS images for PineBook Pro, supporting three media targets:

- internal eMMC
- microSD card
- NVMe SSD

## Board-level requirements

- SoC: Rockchip RK3399
- GPU: Mali-T860 class
- storage: eMMC, microSD, optional NVMe
- display: DRM, panel, backlight
- input: keyboard, touchpad, HID
- networking: Wi-Fi + Bluetooth
- audio: internal speaker and codec support
- power management: battery, charger, suspend/resume

## Build stages

### Stage 1: baseline Linux boot
- verify bootloader works
- confirm kernel launches
- validate storage enumeration
- check serial logs

### Stage 2: board bring-up
- add board definition
- configure the device tree
- add storage-specific overlays
- validate display and input paths

### Stage 3: ChromiumOS integration
- integrate into ChromiumOS build system
- add board support files and scripts
- validate recovery workflow

### Stage 4: storage validation
- eMMC boot
- microSD boot
- NVMe boot

## Storage media order

1. eMMC
2. microSD
3. NVMe

This order keeps the foundation stable and gives a reliable fallback path while the board is still being debugged.

## Expected blockers

- panel timings / display initialization issues
- missing firmware for wireless modules
- keyboard and touchpad misdetection
- power management bugs
- missing GPU or DRM drivers
- SD / eMMC boot quirks
- NVMe enumeration and PCIe timing issues

## Summary

The PineBook Pro RK3399 port should be treated as a staged board bring-up, with eMMC as the primary target, microSD as the flexible recovery path, and NVMe as an advanced storage option.
