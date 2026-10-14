# Storage

The disks the system uses, its partitions, and the files on its FAT
partition. Why the system starts on microSD, and how each disk boots, is in
[STORAGE_STRATEGY.md](STORAGE_STRATEGY.md).

## The disks

| Disk | Linux name | Role |
|------|-----------|------|
| microSD card | `/dev/mmcblk1` | where the image is written and the system runs |
| eMMC | `/dev/mmcblk2` | Manjaro on a factory laptop; nothing writes to it until you move the system there ([INSTALL_TO_EMMC_NVME.md](INSTALL_TO_EMMC_NVME.md)) |
| NVMe SSD | `/dev/nvme0n1` | optional, on the M.2 adapter; the system can be moved there too |

U-Boot calls them `mmc 1`, `mmc 0` and `nvme 0`
([HARDWARE_SPECS.md](HARDWARE_SPECS.md#disks-and-their-names)).

## Partitions

ChromiumOS's own layout (`legacy_disk_layout.json`, as arm64-generic uses it),
with the changes in the overlay's `scripts/disk_layout.json`: a 16 MiB RWFW so
U-Boot fits, 64 MiB kernel partitions, a 128 MiB EFI-SYSTEM, ROOT-A as ext4
and a 5 GiB STATE. In order on the disk:

| # | Name | Size | What it holds |
|---|------|------|---------------|
| 11 | RWFW | 16 MiB | U-Boot (`u-boot-rockchip.bin`, about 9 MiB) at sector 64, where the RK3399 boot ROM reads it. The partition only keeps other data off that space |
| 6, 7, 9, 10 | KERN-C, ROOT-C, reserved | 1 sector each | placeholders of ChromiumOS's layout |
| 2 | KERN-A | 64 MiB | the kernel partition `build_image` writes; this board does not boot from it |
| 4 | KERN-B | 64 MiB | unused |
| 8 | OEM | 16 MiB | unused |
| 12 | EFI-SYSTEM | 128 MiB | FAT, readable on Windows: `boot.scr` and the files below |
| 5 | ROOT-B | 2 MiB | placeholder: there are no A/B updates |
| 3 | ROOT-A | 2 GiB | the system, read-only, ext4 without a journal. `/boot/pinebook-pro/` has `boot.scr`, the kernel `Image` and `rk3399-pinebook-pro.dtb` |
| 1 | STATE | 5 GiB in the image, grown at boot | `/home` (accounts), `/var`, Linux, and the test image's tools in `/usr/local` (about 3.8 GiB) |
| 13 | ANDROID-DATA | what is left at the end | created by Android's setup: ext4 at `/var/lib/waydroid` ([WAYDROID.md](WAYDROID.md#the-android-data-partition)) |

The image file is 7.9 GB: everything up to the end of STATE. On the
project's 64 GB card STATE grew to about 32 GiB and ANDROID-DATA has the last
25 GiB. How STATE grows on other card sizes:
[USER_GUIDE.md](USER_GUIDE.md#space-on-the-card).

ROOT-A has no journal because `build_image` labels its files for SELinux
with extended attributes, which the WSL2 kernel's ext2 driver cannot write.

EFI-SYSTEM keeps 128 MiB: a different size would move ROOT-A and STATE, and
then a newly written image would no longer line up with the Android
partition left on the card.

## Files on EFI-SYSTEM

Windows shows EFI-SYSTEM as a small drive, because `install-u-boot.sh` gives
it the Basic data partition type.

| File | Comes from | What it does |
|------|-----------|--------------|
| `boot.scr` | the image | for boot loaders that look for `/boot.scr` on a FAT partition, like Manjaro's U-Boot on the eMMC |
| `pinebook-collect.sh` | the image | a copy of `pinebook-collect`, easy to find from Windows |
| `google-api-keys.txt` | you | Google API keys for sign-in ([USER_GUIDE.md](USER_GUIDE.md#google-sign-in)) |
| `pinebook-tune.scr` | Pinebook app | overclock and undervolt, applied by `boot.scr`; delete it to go back to the stock values |
| `pinebook-nologs` | you or the Pinebook app | turns the boot logs off |
| `logs\boot-NNNN\`, `logs\last-boot` | `pinebook-boot-logs` | the last 10 boots' logs |
| `logs\collect-<date>-<time>\` | `sudo pinebook-collect` | everything for a bug report |
| `logs\migrate.log` | `pinebook-migrate` | the last move to another disk |
| `pinebook-migrate.json` | Pinebook app | a move waiting for the next boot; removed when it starts |
| `pinebook-boot-emmc`, `pinebook-boot-nvme` | `pinebook-migrate` | `boot.scr` hands over to the copy on that disk; delete to boot the card again |

Writing a new image erases all of them, so copy what you need first.

## In the running system

| Mount point | What |
|-------------|------|
| `/` | ROOT-A, read-only |
| `/mnt/stateful_partition` | STATE, with `/home` and `/var` on it |
| `/var/lib/waydroid` | ANDROID-DATA, while Android is set up and someone is logged in |
| `/run/pinebook-boot-logs/esp` | EFI-SYSTEM, while the boot logs are on; other tools use this mount when it is there |

`rootdev -s -d` names the disk the system booted from; the Pinebook tools
use it to find "their" EFI-SYSTEM, so they also work from the eMMC or an SSD.
