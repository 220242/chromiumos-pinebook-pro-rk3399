# What works on the Pinebook Pro

State on 2026-10-14, component by component, for the test image built from
this repository and run from microSD on one Pinebook Pro (64 GB card, Manjaro
on the eMMC). "Works" means seen on that laptop; the evidence is in the
owner's reports and in the logs `pinebook-collect` saved there. The hardware
itself is described in [HARDWARE_SPECS.md](HARDWARE_SPECS.md); how the
drivers are set up, in [DRIVERS_FIRMWARE.md](DRIVERS_FIRMWARE.md).

## Summary

| Component | State | Notes |
|-----------|-------|-------|
| Boot from microSD | works | Through Manjaro's U-Boot on the eMMC, which finds `boot.scr` on the card's EFI-SYSTEM. The card's own U-Boot, for a laptop without a boot loader on the eMMC, has not been tried yet |
| Login | works | Guest, and Google accounts with your own API keys ([USER_GUIDE.md](USER_GUIDE.md#google-sign-in)). Runs without a TPM |
| Display | works | 14" 1920x1080 eDP panel |
| GPU | works | Mali-T860 with Panfrost (Mesa); Chrome draws on the GPU |
| Keyboard, touchpad | works | One USB device inside the laptop |
| Lid switch, power button | works | |
| Wi-Fi | works | AP6256 (BCM43456) with brcmfmac |
| Bluetooth | adapter found | `hci0` comes up with its firmware patch; nothing paired yet |
| Storage: microSD | works | SDR50 mode, about 23 MB/s with the project's card: the slowest part of the system |
| STATE grows to the card | works | 32 GB STATE and 25 GiB for Android on the 64 GB card |
| Pinebook app | works | |
| Video playback | partly | VP9 plays, decoded on the CPU. H.264 and AAC are missing from the prebuilt Chromium, so YouTube live streams do not play |
| Hardware video decoding | not yet | The decoders are there (`/dev/video-dec0`, `video-dec1`), Chrome does not use them yet |
| Sound | not confirmed | The sound card and CRAS's speaker, headphone and microphone nodes are there; nobody has listened yet |
| Webcam | not confirmed | Detected; see below |
| Linux (Crostini) | not tried | `/dev/kvm`, `vhost-vsock` and `vm_concierge` are there |
| Android (Waydroid) | not yet | The setup page and download work; the container did not start, a fix waits for a test ([WAYDROID.md](WAYDROID.md)) |
| Moving the system to eMMC / NVMe | not tried on the laptop | Tested on disk images ([INSTALL_TO_EMMC_NVME.md](INSTALL_TO_EMMC_NVME.md)) |
| Battery, charger | read | Battery level and both chargers (DC jack, USB-C power delivery) are reported |
| Suspend and resume | not checked | |
| USB-C display output | not checked | Not expected to work yet, see below |
| Brightness and volume keys | not checked | |
| External USB devices | not checked | |
| NVMe SSD | no SSD to try | The PCIe controller times out without one, as expected |

## Notes per component

### Boot

U-Boot 2024.10 with TF-A 2.10 is at sector 64 of the card. On a laptop with
Manjaro on the eMMC the RK3399 boot ROM starts Manjaro's U-Boot first (it
tries the eMMC before the card); that one finds `boot.scr` on the card's
EFI-SYSTEM partition, which `install-u-boot.sh` puts there, and boots the
card. The card's own U-Boot runs only when the eMMC has no boot loader; that
has not been tried on the laptop yet. The boot path and the fixes it needed are in
[PORTING_GUIDE.md](PORTING_GUIDE.md).

The Pinebook Pro has no TPM. The image is built with
`-encrypted_stateful` and `tpm_insecure_fallback` (the same idea as ChromeOS
Flex): without them `chromeos_startup` rebooted on every boot. `trunksd`
still crashes at boot, which is harmless; the TPM services that cryptohome
needs (`tpm_managerd`, `chapsd`) must stay.

SELinux is enforcing, with no denials in the logs.

### Display and GPU

The BOE NV140FHM-N49 panel is driven by the VOP and the Analogix eDP
controller (`card1-eDP-1`), with a PWM backlight. The Mali-T860 uses Panfrost:
the ChromeOS kernel only binds it to the compatible
`"arm,mali-t860-CHROMIUM"`, which `boot.scr` sets in the device tree before
the kernel starts. Chrome composites everything on the GPU: hardware overlay
planes are turned off (`set_hw_overlay_strategy_none`), see Webcam.

The RK3399 can drive a display over USB-C (DisplayPort alt mode, the `cdn-dp`
block). The kernel has the driver and the image has its firmware
(`rockchip/dptx.bin`), but the 6.6 device tree leaves `cdn-dp` disabled, so
USB-C video output is not expected to work until the boot script or the
device tree turns it on.

### Wi-Fi and Bluetooth

Wi-Fi works with the firmware `brcmfmac43456-sdio.bin` (version 7.45.96.2)
once the firmware's own WPA handshake is off: `boot.scr` passes
`brcmfmac.feature_disable=0x82000`. With it on, ChromeOS's `wpa_supplicant`
could not connect.

Bluetooth (BCM4345C5 over UART0) registers as `hci0` and loads its patch
`BCM4345C5.pine64,pinebook-pro.hcd`; pairing a device has not been tried.

### Storage

| Disk | Device | Seen on the laptop |
|------|--------|--------------------|
| microSD | `/dev/mmcblk1` | SDR50 SDXC card, 59.6 GiB |
| eMMC | `/dev/mmcblk2` | HS200, 58.2 GiB, Manjaro on it |
| SDIO Wi-Fi | `mmc0` | SDR104 |
| NVMe | `/dev/nvme0n1` | none installed; the PCIe controller reports a link training timeout at boot |

Partition layout and boot order: [STORAGE.md](STORAGE.md).

### Video

Chrome can only use hardware decoders it finds at `/dev/video-dec*`; the
board's udev rules create them:

| Device | Driver | Decodes (kernel 6.6) |
|--------|--------|---------------------|
| `/dev/video-dec0` | rkvdec | H.264, VP9 (the hardware also does HEVC; this driver version does not) |
| `/dev/video-dec1` | Hantro VPU | VP8, MPEG-2 |
| `/dev/video-enc0` | Hantro VPU | encodes JPEG only, so no H.264 or VP8 encoding for video calls |

Chrome needs buffers the decoder and the GPU can share; the image has a
Panfrost backend for minigbm for that. Chrome still decodes on the CPU: the
latest image logs how Chrome chooses its decoders, to find out why. The Pinebook app shows which decoder is in use (*Видеодекодер*).

Codecs: the prebuilt Chromium of the ChromiumOS build has no H.264, AAC or
other proprietary codecs, so YouTube live streams (H.264 with AAC) only show
that the video cannot be played in this browser. Chrome is being built from
source with them ([build/README.md](../build/README.md#chrome-from-source)).

### Sound

The ES8316 codec with the speaker amplifier registers as the sound card
`rockchip,es8316-codec`, and the board's UCM files make CRAS list
*Speaker*, *Headphone* (with jack detection) and *Internal Mic*. Whether
sound comes out has not been reported yet.

### Webcam

The USB camera (0c45:6321) is detected. When the Camera app was opened,
Chrome kept allocating display buffers until the 4 GB of RAM ran out and its
processes were killed. Since then the image turns hardware overlays off,
which should stop that; the camera has not been tried again.

### Power

The CW2015 fuel gauge reports the battery (10,000 mAh design), and both
chargers are seen: the DC jack, and USB-C power delivery through the
FUSB302. The Pinebook app shows them, the RK808 power rails, and switches the
LEDs, Wi-Fi power saving, the big CPU cores and the sleep mode
([USER_GUIDE.md](USER_GUIDE.md#the-pinebook-app)). Suspend and resume have
not been tried.

CPU frequency scaling works (A53 up to 1416 MHz, A72 up to 1800 MHz); the
Pinebook app can add 1512/1992 MHz or 1608/2088 MHz steps and undervolt, at
the next boot.

## Next

The order of work is in [BUILD_PLAN.md](BUILD_PLAN.md).
