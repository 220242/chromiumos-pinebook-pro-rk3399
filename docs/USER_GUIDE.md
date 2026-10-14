# User guide

How to put the image on a microSD card and use it on a Pinebook Pro: first
boot, Google sign-in, the Pinebook app, logs and what to do when something
goes wrong. Building the image is in [build/README.md](../build/README.md)
(on Windows: [WINDOWS_BUILD.md](WINDOWS_BUILD.md)); what works on the laptop
is in [HARDWARE.md](HARDWARE.md).

The Pinebook app's pages are in Russian, so its buttons are named here as
they appear, with a translation.

## Writing the card

Use a microSD card of 64 GB or more. The image fits a 16 GB card, but on
cards of 32 GB and less the partition for your data stays at 5 GB, most of
which the test image's own tools take (see
[Space on the card](#space-on-the-card)). Writing erases the whole card.

- **Windows:** [balenaEtcher](https://etcher.balena.io/) or
  [Rufus](https://rufus.ie/) with the image file
  `chromiumos-pinebook-pro-rk3399-test.bin` (about 7.9 GB).
- **Linux:** `build/linux/flash-microsd.sh /dev/sdX` (it asks you to type the
  device name before writing), or `dd`.

The `.sha256` file next to the image holds its checksum. In PowerShell,
`Get-FileHash -Algorithm SHA256 <image>` prints the same value if the file is
intact.

The image is complete as it is: U-Boot is at sector 64 and the boot script is
on the card's FAT partition, EFI-SYSTEM, which Windows shows as a small
drive.

### Before writing a new image to a card you already use

Writing an image erases ChromiumOS's data on the card: accounts, files,
settings, Linux, and the files you put on EFI-SYSTEM. Copy what you need from
the EFI-SYSTEM drive to the PC first and put it back after writing:

- `google-api-keys.txt`, your Google API keys (see
  [Google sign-in](#google-sign-in));
- `pinebook-tune.scr`, if you set an overclock or undervolt;
- `logs\`, if you still need old logs.

Android's partition is outside the image and survives when the new image has
the same size as the old one ([WAYDROID.md](WAYDROID.md#the-android-data-partition)).
Updating the system without losing the data is planned, not done
([BUILD_PLAN.md](BUILD_PLAN.md)).

## First boot

Put the card in and switch the laptop on. What starts the system depends on
what else the laptop has:

- On a Pinebook Pro that came with Manjaro, the Manjaro boot loader on the
  eMMC starts first, finds `boot.scr` on the card's EFI-SYSTEM and boots the
  card. Without the card, Manjaro starts as before; nothing on the eMMC is
  changed.
- With an empty eMMC (or none), the RK3399 starts the U-Boot on the card.
  This has not been tried on the laptop yet.
- A boot loader in the SPI flash (Tow-Boot, for example) would start before
  both. Like Manjaro's, it should find `boot.scr`, but that has not been
  tried.

On the first boot the partition for your data (STATE) grows into the free
space of the card, which takes a few seconds and needs no restart.

### Space on the card

The image's STATE partition is 5 GB. At every boot `pinebook-grow-stateful`
checks it, and once it grows it to the end of the card minus 25 GiB, which is
left free for Android:

| Card | STATE (your data, Linux) | Left for Android |
|------|--------------------------|------------------|
| 16 GB | 5 GB | about 7 GB |
| 32 GB | 5 GB | about 22 GB |
| 64 GB | about 32 GB | 25 GiB |
| 128 GB | about 90 GB | 25 GiB |

On cards of 32 GB and smaller there is not enough room to grow STATE and
keep 25 GiB, so STATE stays at 5 GB, of which the test image's tools in
`/usr/local` take about 3.8 GB. Once Android's partition exists, STATE is not
grown any more. Moving the system to the eMMC lets you choose the
split again ([INSTALL_TO_EMMC_NVME.md](INSTALL_TO_EMMC_NVME.md)).

### Logging in

ChromiumOS has no local accounts. On the login screen:

- **Browse as Guest** works right away. A guest session keeps nothing after
  logging out and has no Linux.
- **A Google account** needs your own Google API keys first (next section).
  The first account to sign in becomes the device's owner.

### The shell (VT2)

This is a test image, which has a text console: press **Ctrl+Alt+F2**, log in
as `chronos` with the password `test0000`; `sudo` asks for the same password.
**Ctrl+Alt+F1** goes back to the desktop. On the desktop, Ctrl+Alt+T opens
crosh, whose `shell` command gives the same shell.

## Google sign-in

Google gives API keys only to its own Chrome builds, so a Chromium build like
this one cannot sign in to Google until you add your own:

1. Make the keys as described in
   [Chromium's API keys guide](https://www.chromium.org/developers/how-tos/api-keys/):
   an API key and an OAuth client (ID and secret).
2. With the Google account you want to sign in with, join the Google groups
   [chromium-dev](https://groups.google.com/a/chromium.org/g/chromium-dev),
   which lets the Google Cloud console offer Chrome's APIs for your keys, and
   [google-browser-signin-testaccounts](https://groups.google.com/a/chromium.org/g/google-browser-signin-testaccounts),
   without which Google refuses that account's sign-in to a Chromium OS
   build.
3. Give the keys to the laptop in one of two ways:
   - **A file.** On the PC, create `google-api-keys.txt` in the root of the
     card's EFI-SYSTEM drive with three lines, your values after the `=`:

     ```
     GOOGLE_API_KEY=your-api-key
     GOOGLE_DEFAULT_CLIENT_ID=your-client-id.apps.googleusercontent.com
     GOOGLE_DEFAULT_CLIENT_SECRET=your-client-secret
     ```

     Notepad is fine: spaces, quotes, the BOM and Windows line endings are
     handled, and so is a `.txt.txt` name that Windows hides.
   - **The Pinebook app.** As a guest: *Настройки* (Settings) → *Вход в
     аккаунт Google* (Google sign-in), fill in the three fields, press
     *Сохранить ключи* (Save keys) and log out. Chrome starts again with them.

   The file on EFI-SYSTEM wins when both exist. Keys saved in the app are
   lost when a new image is written; the file is lost too unless you copy it
   off first.

The keys are yours: don't post them, and when you send logs, send the `logs`
folder, not the whole EFI-SYSTEM drive. `pinebook-collect` records only how
many key lines Chrome got (`chrome-keys.txt`), not the keys.

## The Pinebook app

**Pinebook** in the launcher, or http://pinebook.localhost:8086 in Chrome. It
is the page of a service that runs as root on the laptop and answers only on
the laptop itself.

| Tab | What is there |
|-----|---------------|
| *Мониторинг* (Monitor) | CPU frequency and load per core, the Mali-T860 GPU, temperatures, power draw, memory, and which programs use the GPU and the hardware video decoders (*Видеодекодер*). *Оверлей* opens a small window that stays on top of the others. |
| *Питание* (Power) | Battery, charger (DC jack, or the USB-C power contract), a graph of the last 3 hours, the two LEDs, Wi-Fi power saving, *Только A53* (only the four small cores, to save power) or *Все ядра* (all cores), the sleep mode (s2idle or deep), and the PMIC RK808 power rails (read only: the kernel does not let them be changed). |
| *Железо* (Hardware) | The laptop's devices with their drivers and firmware: storage, display, Wi-Fi and Bluetooth, sound, USB, sensors, the system version. |
| *Настройки* (Settings) | *Режим работы* (operating mode): *Экономия* (power saving), *Сбалансированный* (balanced), *Производительность* (performance) or *Свой* (custom CPU and GPU limits), applied at once and after reboots. Google API keys. Boot logs on or off. [Moving the system](INSTALL_TO_EMMC_NVME.md) to the eMMC or an NVMe SSD. Overclocking and undervolting. |

**Overclocking and undervolting** (*Разгон и андервольтинг*) take effect at
the next boot: the app writes `pinebook-tune.scr` to EFI-SYSTEM, which
changes the CPU and GPU frequency tables before the kernel starts.

| Setting | Values |
|---------|--------|
| Overclock | off (A53 1416 MHz, A72 1800 MHz, as the stock device tree), *Умеренный* (A53 1512, A72 1992 MHz), *Сильный* (A53 1608, A72 2088 MHz) |
| Undervolt, CPU and GPU separately | 0, 25, 50, 75 or 100 mV below the stock voltages |

If the laptop does not boot or hangs after that, delete `pinebook-tune.scr`
from the card's EFI-SYSTEM on any computer: the next boot uses the stock
values.

## Android apps and Linux

- **Android:** the **Android** app in the launcher sets up Waydroid on first
  use (a partition at the end of the card and a 1 GB download). See
  [WAYDROID.md](WAYDROID.md); on the laptop it does not start yet.
- **Linux (Crostini):** *Settings → About ChromeOS → Developers → Linux
  development environment*, signed in with a Google account (not as a guest).
  The image has it and `/dev/kvm` exists, but it has not been tried on the
  laptop yet.

## Logs

Logs end up on the card's EFI-SYSTEM drive, so they can be read on Windows.

- **Every boot** writes `logs\boot-NNNN\` there, and on any FAT USB stick
  that is plugged in during the first five minutes; the last 10 boots are
  kept. `cmdline.txt`, `dmesg.txt`, `state.txt` and copies of the system logs
  are updated every second for five minutes, then every 30 seconds. To
  switch this off: *Настройки → Логи загрузки* in the app, or an empty file
  named `pinebook-nologs` in the root of EFI-SYSTEM.
- **Everything at once:** in the shell (Ctrl+Alt+F2, `chronos` /
  `test0000`), run `sudo pinebook-collect`. It saves hardware state, the
  system and Chrome logs to `logs\collect-<date>-<time>\` on EFI-SYSTEM (or to
  `/var/log/pinebook-collect/` when no FAT disk is mounted).
- **Moving the system:** `logs\migrate.log`.
- **Android:** `/var/log/pinebook-android.log`, also shown on the Android
  page.

Then switch off, put the card in the PC and copy the `logs` folder.

## When something goes wrong

| Problem | What to do |
|---------|------------|
| Manjaro starts instead of ChromiumOS | Check that the card is in all the way and that EFI-SYSTEM has `boot.scr` in its root (the image puts it there). |
| No boot after changing *Разгон и андервольтинг* | Delete `pinebook-tune.scr` from EFI-SYSTEM. |
| The laptop boots the eMMC or SSD copy, but you want the card | Delete `pinebook-boot-emmc` (or `pinebook-boot-nvme`) from the card's EFI-SYSTEM. |
| Google sign-in fails | Check the three lines of `google-api-keys.txt` and the two Google groups. `sudo pinebook-collect`, then `chrome-keys.txt` shows how many key lines Chrome got (3 when all is well). |
| A video does not play | Live streams on YouTube need H.264 and AAC, which the current image's Chromium lacks; a Chrome built from source with them is in progress. Other videos play, decoded on the CPU. |
| Stuck at the boot logo, black screen, reboot loop | The boot logs on EFI-SYSTEM usually show why: send the newest `logs\boot-NNNN`. |
| Nothing at all on the screen | A serial console shows U-Boot and the kernel: 1,500,000 baud, 3.3 V, on the headphone jack once the switch on the mainboard turns it into a serial port (see the [Pine64 wiki](https://wiki.pine64.org/wiki/Pinebook_Pro)). |
