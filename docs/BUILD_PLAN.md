# Plan

What has been done, what is in progress and what could come next. State on
2026-10-14; what works on the laptop, part by part, is in
[HARDWARE.md](HARDWARE.md).

## Done

- **The port builds:** the board overlay goes through `setup_board`,
  `build_packages` and `build_image` in the ChromiumOS SDK (`stable` manifest,
  Chrome 157, kernel 6.6), on a Windows PC with WSL2. Single packages go into
  the last image in minutes with the `patch` stage
  ([build/README.md](../build/README.md)).
- **It boots on the Pinebook Pro** from microSD, through Manjaro's U-Boot
  on the eMMC, to the desktop: display, GPU (Panfrost), keyboard,
  touchpad, lid, power button, Wi-Fi.
- **Login:** Guest and Google accounts, without a TPM; Google sign-in with
  your own API keys from a file on the card or from the Pinebook app.
- **The card is used in full:** STATE grows at boot, leaving 25 GiB for
  Android.
- **The Pinebook app:** monitor, power modes, power and hardware pages,
  overclocking and undervolting.
- **Bring-up tools:** boot logs on EFI-SYSTEM, `sudo pinebook-collect`.

Built and in the image, waiting for a test on the laptop:

- moving the system to the eMMC or an NVMe SSD, with the advanced options
  (tested on disk images);
- Android: the fix for starting its container;
- sound (CRAS sees the speakers, headphones and microphone), Linux
  (Crostini), the webcam with hardware overlays off;
- the card's own U-Boot, for a laptop without a boot loader on the eMMC.

## In progress

- **Chrome from source** with H.264, AAC and the other proprietary codecs, so
  YouTube live streams play (the owner's decision of 2026-10-13). It is
  compiling on the project's PC: 28,000 of 78,000 steps on 2026-10-13 at
  23:00 UTC, slowed by the laptop CPU throttling to about 1.3 GHz.
- **Hardware video decoding:** the decoders and the minigbm backend are in
  place, but Chrome still decodes on the CPU. The latest image logs how
  Chrome chooses a decoder; a log from a video played for a minute will
  show the next step.
- **Android:** after the owner's test of the container fix.

## Next

Proposed, not decided yet:

1. **Updating without losing data:** write only the system partitions
   (U-Boot, ROOT-A, the boot files on EFI-SYSTEM) to a card or eMMC in use,
   keeping accounts, Linux and Android.
2. **Checks on the laptop:** suspend and resume with the lid, brightness and
   volume keys, sound, Bluetooth pairing, the webcam, Linux.
3. **Moving the system to the eMMC** on the laptop itself, which also ends
   the slow card (about 23 MB/s at SDR50).
4. **USB-C display output:** the kernel driver and its firmware are there,
   but the 6.6 device tree leaves the DisplayPort block (`cdn-dp`) disabled;
   enabling it at boot, the way `boot.scr` already fixes the GPU node, is
   the likely first step.
5. **A newer Mesa:** the image has Mesa 23.3; a newer one would bring 3D
   fixes (not codecs or video decoding), at the risk of breaking how the
   desktop draws. A separate step with its own test.

Limits of the current kernel, worth knowing before planning:

- **Hardware video encoding** (for video calls): on the RK3399 the 6.6
  kernel's Hantro driver encodes JPEG only, so H.264 or VP8 encoding needs
  driver work.
- **HEVC:** Chrome is built with it, but Chrome decodes HEVC only in
  hardware, and the 6.6 rkvdec driver has H.264 and VP9 only.
