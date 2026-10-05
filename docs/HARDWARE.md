# Hardware notes for PineBook Pro RK3399

This document tracks the hardware-specific items relevant to a ChromiumOS port for the PineBook Pro using RK3399.

## Baseline hardware

- Board: PineBook Pro
- SoC: Rockchip RK3399
- CPU: ARMv8 big.LITTLE (A72 + A53)
- GPU: Mali-T860 or equivalent class
- Memory: 4GB LPDDR4
- Display: internal panel, likely needing DRM and panel support
- Storage: eMMC, microSD, optional NVMe
- Input: keyboard, touchpad, USB, possibly a custom input controller
- Audio: Everest Semi ES8316 codec on I2S1, internal speakers
- Wireless: AMPAK AP6256 (Broadcom BCM43456 Wi-Fi on SDIO via brcmfmac, BCM4345C5 Bluetooth on UART)

## Key support areas

### 1. Display and graphics

- Check panel name and timing parameters
- Confirm display pipeline is managed by DRM/KMS
- Validate backlight and brightness controls
- Check GPU driver support for RK3399 / Mali-T860

### 2. Input devices

- identify keyboard controller and matrix layout
- ensure touchpad works through PS/2, I2C, or HID path
- confirm suspend/resume input behavior

### 3. Audio

- verify internal speaker and headphone path
- confirm codec driver and sound card registration
- test mixer state and power management

### 4. Wireless

- identify Wi-Fi chipset and firmware
- validate Bluetooth pairing behavior
- ensure module powers correctly on boot and resume

### 5. Storage

- confirm eMMC controller and SD card controller support
- review NVMe compatibility and storage enumeration
- ensure boot media is selected correctly in U-Boot

### 6. Power management

- suspend/resume support
- thermal behavior
- battery status and AC power reporting
- charger and PMIC integration

## Known PineBook Pro hardware complexity

PineBook Pro boards often require:

- vendor firmware blobs
- patched kernel device trees
- custom power management settings
- platform-specific display and input quirks

## Debugging checklist

Before building a ChromiumOS image, confirm:

- kernel boots on the board
- storage devices are recognized
- display output is stable
- keyboard and touchpad function
- sound works
- wireless modules load correctly
- battery and charging state are readable

## Hardware support matrix

| Component | Status | Notes |
| --- | --- | --- |
| eMMC | needed | main internal storage |
| microSD | required for tests | good fallback path |
| NVMe | optional | useful extra storage path |
| display | early port area | DRM and panel timing required |
| audio | early port area | driver and mixer validation needed |
| Wi-Fi / BT | required | vendor firmware likely needed |
| touchpad | required | input path likely needs tuning |
| battery / PMIC | required | power management important |

## Priority order for porting

1. bootloader and storage recognition
2. kernel boot and device tree sanity
3. display output
4. keyboard/touchpad input
5. wireless
6. audio
7. power management and suspend

## Useful references

- Pine64 hardware documentation: https://wiki.pine64.org/wiki/PineBook_Pro
- Armbian PineBook Pro support: https://www.armbian.com/pinebook-pro/
- Rockchip RK3399 Linux support: https://github.com/rockchip-linux
- upstream Linux kernel: https://www.kernel.org/

## Summary

The PineBook Pro RK3399 port is feasible, but the hardware supports multiple subsystems that each need validation. Successful ChromiumOS bring-up depends on careful device-tree tuning, firmware support, and targeted kernel work across storage, sound, input, display, and wireless.
