# Storage strategy

Why the system starts on a microSD card, how it boots from each disk, and
what updates and recovery look like. The partitions themselves are in
[STORAGE.md](STORAGE.md).

## microSD first

The image is written to a microSD card and runs from it:

- **Nothing on the laptop changes.** The eMMC, with Manjaro on a factory
  laptop, is not written to; without the card, the laptop starts as before.
- **Easy to try and to undo.** A new image is one card write, and a card
  that does not boot is simply taken out.
- **A fallback.** Even after the system has been moved to the eMMC, U-Boot
  looks at the card first, so a card with a fresh image always boots.

The price is speed: the slot runs at SDR50, and the project's card gives
about 23 MB/s, so installs, logins and Android are slow. Once the system works for
you, move it to the eMMC with the Pinebook app
([INSTALL_TO_EMMC_NVME.md](INSTALL_TO_EMMC_NVME.md)).

There is only one image: the same partitions and the same boot script work
from the card, the eMMC and an NVMe SSD. `boot.scr` boots the ROOT-A of the
disk it was loaded from, by its PARTUUID, and the move to another disk gives
every partition new unique GUIDs, so two copies never mix.

## How each disk boots

The RK3399 boot ROM runs the first boot loader it finds at sector 64 of the
SPI flash, the eMMC, then the microSD card.

### From the card

- **Manjaro on the eMMC** (a factory laptop): the boot ROM starts Manjaro's
  U-Boot. Its standard boot finds `/boot.scr` on the card's EFI-SYSTEM (the
  partition marked bootable) and runs it.
- **Empty eMMC** (not tried on the laptop yet): the boot ROM starts the
  U-Boot on the card. Its `bootcmd` loads `/boot/pinebook-pro/boot.scr` from
  ROOT-A of the card (`mmc 1:3`), then of the eMMC (`mmc 0:3`); if neither
  has one, it falls back to U-Boot's standard boot, so other systems still
  start.

Either way `boot.scr` loads the kernel and device tree from the card's ROOT-A,
sets the GPU's compatible string, applies `pinebook-tune.scr` if there is one,
and starts the kernel with `root=PARTUUID=<ROOT-A>`.

### From the eMMC, after moving the system there

The copy has its own U-Boot at sector 64, in place of Manjaro's, so the boot
ROM starts it with or without the card:

- without a card, `bootcmd` finds nothing on `mmc 1` and boots the eMMC;
- with the old card in, `bootcmd` loads the card's `boot.scr` first, which
  sees `pinebook-boot-emmc` on the card's EFI-SYSTEM and hands over to the
  eMMC's `boot.scr`;
- with a card that has another ChromiumOS image and no such file, that card
  boots.

### From an NVMe SSD

The boot ROM cannot start from PCIe, so U-Boot keeps coming from the card
(or the eMMC). The card's `boot.scr` sees `pinebook-boot-nvme`, runs
`pci enum; nvme scan` and runs the SSD's `boot.scr`, which boots the SSD.
The card has to stay in.

## Updating

- **Today:** a new image is written to the card, which erases accounts,
  files, settings and Linux. Android's partition survives an image of the
  same size ([WAYDROID.md](WAYDROID.md#the-android-data-partition)).
- **Developers** change single packages with the build's `patch` stage, but
  that patches the image on the PC, not a card in use.
- **Planned:** an update that rewrites only the system partitions (U-Boot,
  ROOT-A, the boot files on EFI-SYSTEM) on a card or eMMC in use, keeping
  STATE and Android ([BUILD_PLAN.md](BUILD_PLAN.md)).

There are no automatic updates: ChromiumOS's A/B update path needs Google's
update server, which knows nothing of this board.

## Recovery

| Situation | Way out |
|-----------|---------|
| No boot after an overclock or undervolt | Delete `pinebook-tune.scr` from the card's EFI-SYSTEM |
| The system was moved, and you want the card back | Delete `pinebook-boot-emmc` or `pinebook-boot-nvme` from the card's EFI-SYSTEM |
| The copy on the eMMC does not boot any more | Boot a card with a fresh image: the eMMC's U-Boot tries the card first |
| The eMMC should not start anything | From a system running on the card, erase the eMMC's first 16 MiB (its partition table and U-Boot) |
| You want Manjaro back on the eMMC | Moving the system erased it; write Manjaro's own image to the eMMC again |
