# Moving the system from microSD to the eMMC or an NVMe SSD

A system set up on the microSD card can be moved, as it is, to the
Pinebook Pro's eMMC or to an NVMe SSD in the M.2 slot: user accounts and
their encrypted files, settings, Linux (Crostini) and Android (Waydroid).
The eMMC is much faster than a card, and from the eMMC the laptop starts
without the card.

**Status:** tested on disk images (see [Testing](#testing)), not yet run on
the laptop itself.

## How to do it

1. Plug in the charger.
2. Open the **Pinebook** app, *Настройки* (Settings), the card *Перенос
   системы на eMMC или NVMe* (moving the system to the eMMC or NVMe).
3. Pick the eMMC or the SSD. The chosen disk is **erased** entirely: on a
   Pinebook Pro bought with Manjaro, the eMMC holds Manjaro.
4. Optionally open *Расширенный режим* (advanced mode), below.
5. Tick *Я понимаю, что всё на выбранном диске будет стёрто* (I understand
   that everything on the chosen disk will be erased) and press *Перенести
   при следующей загрузке* (move at the next boot). *Отменить* (cancel)
   withdraws the request.
6. Press *Перезагрузить сейчас* (restart now). The copy runs before the
   login screen and shows its progress on the screen. It takes from a few
   minutes to about half an hour (the card is the slow part); then the
   laptop restarts from the new disk.

The log of the last run is in the app (*Журнал последнего переноса*) and in
`logs\migrate.log` on the card's EFI-SYSTEM partition, readable from Windows.

### Advanced mode

| Setting | Choices | Default |
|---------|---------|---------|
| *Что переносить* (what to move) | *Всё* (everything), or *Чистую систему* (a clean system, as after a powerwash: no accounts, their files or the device owner; system software such as the Linux VM image stays) | everything |
| *Место под Android в конце диска, ГБ* (space for Android at the end of the disk, GB) | a number, or *Без Android* (none), *Android 8 ГБ*, *16 ГБ*, *25 ГБ*, *Пополам* (half of the disk) | 25 |
| *Перенести данные Android* (copy Android's data) | on: ANDROID-DATA is copied into that space; off: the space stays empty and Android is set up there from scratch | on |
| *Загружаться с нового диска* (boot from the new disk) | off: the card stays the system that boots, and the copy is a spare | on |
| *Перезагрузиться сразу после копирования* (restart right after copying) | off: the boot carries on from the card after copying | on |

The rest of the disk goes to STATE, ChromeOS's own data. *Показать
разметку* (show the layout) draws the partitions the disk would get, and the
app refuses a layout that does not fit: ChromeOS's data needs the space it
uses on the card plus 1 GiB, copied Android data the same, and Android at
least 4 GiB.

## What happens

`pinebook-migrate` (package `chromeos-base/pinebook-control`) writes the
request, `pinebook-migrate.json`, to the card's EFI-SYSTEM. At the next boot
`boot.scr` sees it and adds `pinebook.migrate=1` to the kernel command line,
and the upstart job `pinebook-migrate` (`start on starting startup`) runs
before `chromeos_startup` mounts the stateful partition:

1. The request is removed first, so a failed run is not repeated.
2. A new GPT is written on the target: the same partitions at the same
   sectors with new unique GUIDs (so the card and the copy never share a
   PARTUUID), STATE up to the space chosen for Android, ANDROID-DATA after
   it if its data is copied, and the backup GPT at the end of the disk.
3. Partitions 2-12 are copied raw: kernels, root file systems, OEM, RWFW
   (U-Boot at sector 64) and EFI-SYSTEM.
4. STATE and ANDROID-DATA are copied with `e2image -ra` (only used blocks).
   If the target's STATE is smaller than the card's file system, the card's
   file system is shrunk first (`resize2fs`); the copies are grown to fill
   their partitions. `pinebook-grow-stateful` grows the card's STATE back if
   the card is booted again. For a clean system, accounts, their files, the
   device owner and logs are then removed from the copy.
5. Unless the new disk is only a spare, `pinebook-boot-emmc` (or
   `pinebook-boot-nvme`) is left on the card's EFI-SYSTEM, and the laptop
   restarts.

On any error the run stops, writes the log and the boot continues from the
card as before.

## Booting afterwards

- **eMMC:** the copy has U-Boot at sector 64, and the RK3399 boot ROM tries
  the eMMC before the card, so the laptop starts from the eMMC with or
  without the card. U-Boot's `bootcmd` still looks at the card first; the
  card's `boot.scr` sees `pinebook-boot-emmc` and hands over to the eMMC's
  `boot.scr`.
- **NVMe:** the boot ROM cannot start from an SSD. U-Boot stays on the card
  (or on the eMMC): its `boot.scr` sees `pinebook-boot-nvme`, runs
  `pci enum; nvme scan` and boots the SSD's copy. Keep the card in.
- **Back to the card:** delete `pinebook-boot-emmc` / `pinebook-boot-nvme`
  from the card's EFI-SYSTEM (from any computer). To stop the eMMC from
  booting at all, erase its first 16 MiB.

Android follows the system: it uses ANDROID-DATA on the disk the system runs
from, and a card left in the slot is not touched
([WAYDROID.md](WAYDROID.md#the-android-data-partition)).

## Testing

`pinebook-migrate run --source /dev/loopX --force` works on loop devices
(loop targets are allowed, no reboot): a 59.6 GB image of the card with a
grown STATE and ANDROID-DATA was moved to a 58.2 GB "eMMC" holding another
OS. Root file system and U-Boot came out identical, STATE was shrunk to fit
and both copies passed `e2fsck -f`, file contents matched, and the
PARTUUIDs differ. The advanced options were tried the same way on 32, 120
and 16 GB disk images.
