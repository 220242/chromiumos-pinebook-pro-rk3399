# Moving the system from microSD to the eMMC or an NVMe SSD

A system set up on the microSD card can be moved, as it is, to the
Pinebook Pro's eMMC or to an NVMe SSD in the M.2 slot: user accounts and
their encrypted files, settings, Linux (Crostini) and Android (Waydroid).

## How to do it

1. Plug in the charger.
2. Open the **Pinebook** app, *Settings → Moving the system*, pick the eMMC
   or the SSD, tick the confirmation and press *Move at the next boot*.
   The chosen disk is **erased** (on a Pinebook Pro bought with Manjaro, the
   eMMC holds Manjaro).
3. Press *Restart now*. The copy runs before the login screen; its progress
   is shown on the screen. It takes from a few minutes to about half an hour
   (the microSD card is the slow part), then the laptop restarts from the new
   disk.

The log of the last run is in the app and in `logs/migrate.log` on the
card's EFI-SYSTEM partition (readable from Windows).

## What happens

`pinebook-migrate` (package `chromeos-base/pinebook-control`) writes the
request, `pinebook-migrate.json`, to the card's EFI-SYSTEM. At the next boot
`boot.scr` sees it and adds `pinebook.migrate=1` to the kernel command line,
and the upstart job `pinebook-migrate` (`start on starting startup`) runs
before `chromeos_startup` mounts the stateful partition:

1. The request is removed first, so a failed run is not repeated.
2. A new GPT is written on the target: the same partitions at the same
   sectors with new unique GUIDs (so the card and the copy never share a
   PARTUUID), STATE up to 25 GiB before the end of the disk and ANDROID-DATA
   after it (the same rule as `pinebook-grow-stateful`), and the backup GPT
   at the end of the disk.
3. Partitions 2-12 are copied raw: kernels, root file systems, OEM, RWFW
   (U-Boot at sector 64) and EFI-SYSTEM.
4. STATE and ANDROID-DATA are copied with `e2image -ra` (only used blocks).
   If the target's STATE is smaller than the card's file system, the card's
   file system is shrunk first (`resize2fs`); the copies are grown to fill
   their partitions. `pinebook-grow-stateful` grows the card's STATE back if
   the card is booted again.
5. `pinebook-boot-emmc` (or `pinebook-boot-nvme`) is left on the card's
   EFI-SYSTEM and the laptop restarts.

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

## Testing

`pinebook-migrate run --source /dev/loopX --force` works on loop devices
(loop targets are allowed, no reboot): a 59.6 GB image of the card with a
grown STATE and ANDROID-DATA was moved to a 58.2 GB "eMMC" holding another
OS. Root file system and U-Boot came out identical, STATE was shrunk to fit
and both copies passed `e2fsck -f`, file contents matched, and the
PARTUUIDs differ.
