# Building on Windows with WSL2

ChromiumOS only builds on x86_64 Linux. On Windows the build runs inside
WSL2, with the same scripts as on Linux (`build/linux/*.sh`, described in
[build/README.md](../build/README.md)); `build/windows/Start-PinebookBuild.ps1`
starts them from PowerShell.

The project's images are built this way, on a Windows laptop with an Intel
i7-9750H, in a WSL2 distro of its own whose virtual disk is on the D: drive.

## 1. Prepare WSL2

```powershell
wsl --install -d Ubuntu-22.04
wsl -l -v            # VERSION must be 2
```

Give WSL enough memory. Create `%UserProfile%\.wslconfig`:

```ini
[wsl2]
memory=16GB
swap=16GB
```

Then run `wsl --shutdown` so it takes effect.

### Disk space, and keeping the build off C:

The distro's virtual disk (`ext4.vhdx`) grows while the build fills it and
does not shrink by itself. The checkout, the SDK and one board build need
about 200 GB, which is what `preflight.sh` checks; building Chrome from
source needs much more (on the project's PC the virtual disk is at about
375 GB).

To keep it on another drive, copy the distro there under a name of its own:

```powershell
wsl --export Ubuntu-22.04 D:\ubuntu-22.04.tar
wsl --import chromiumos-build D:\Chromiumos\wsl D:\ubuntu-22.04.tar
Remove-Item D:\ubuntu-22.04.tar
```

An imported distro logs in as root. To log in as your user, put this in its
`/etc/wsl.conf` (with your user name), then run
`wsl --terminate chromiumos-build`:

```ini
[user]
default=yourname
```

Pass `-Distro chromiumos-build` to the build script, or make it the default
with `wsl --set-default chromiumos-build`.

### Tools inside the distro

Install the host tools and set a git identity (`repo` needs it). The
ChromiumOS tools need Python 3.11 or newer; Ubuntu 22.04's `python3` is 3.10,
so install `python3.11` too and the scripts use it automatically. `mtools`
and `fdisk` are for putting the boot loader into the image.

```bash
sudo apt update
sudo apt install -y git curl xz-utils python3 python3.11 rsync mtools fdisk
git config --global user.name  "Your Name"
git config --global user.email "you@example.com"
```

## 2. Where the files live

| What | Where | Why |
|------|-------|-----|
| ChromiumOS checkout | `~/chromiumos` inside WSL | must be on the Linux file system; `/mnt/c`, `/mnt/d` are slow, case-insensitive and rejected by the scripts |
| depot_tools | `~/depot_tools` inside WSL | |
| This repository | anywhere, e.g. `D:\chromiumos-pinebook-pro-rk3399` | small; can stay on Windows |
| Finished image and logs | `<this repo>\output\` | readable from Windows for writing the card |

`.gitattributes` keeps the `.sh` files with LF line endings even when the
repository is cloned on Windows. If the scripts were checked out with CRLF
before that, the PowerShell script stops and prints how to fix it.

## 3. Build from PowerShell

```powershell
git clone https://github.com/220242/chromiumos-pinebook-pro-rk3399.git D:\chromiumos-pinebook-pro-rk3399
cd D:\chromiumos-pinebook-pro-rk3399

.\build\windows\Start-PinebookBuild.ps1                  # preflight, sync, build
```

If PowerShell refuses to run scripts, allow local ones once:
`Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`.

Useful parameters:

```powershell
.\build\windows\Start-PinebookBuild.ps1 -Step Preflight          # check only
.\build\windows\Start-PinebookBuild.ps1 -Step Sync               # fetch source only
.\build\windows\Start-PinebookBuild.ps1 -Step Build -Stage packages,image
# A changed package into the last image, in minutes (bump its -rN first):
.\build\windows\Start-PinebookBuild.ps1 -Step Build -Stage overlay,patch -Package chromeos-base/pinebook-control
.\build\windows\Start-PinebookBuild.ps1 -Distro chromiumos-build -ImageType dev
.\build\windows\Start-PinebookBuild.ps1 -DryRun                  # print commands only
```

`Get-Help .\build\windows\Start-PinebookBuild.ps1 -Full` lists all of them.
`cros_sdk` asks for your Linux sudo password in the same window. Which stages
a change needs is in
[build/README.md](../build/README.md#which-build-for-which-change).

### Long builds on a laptop

The first build compiles Chrome, which takes more than a day on the
project's laptop. Under hours of full load a laptop CPU slows down to keep
cool (the i7-9750H fell from 2.6 to about 1.3 GHz), so:

- keep the charger in;
- set Windows' power mode to *Best performance* and keep the laptop from
  sleeping while it builds;
- give it air: a stand, or at least not a soft surface.

If a build is stopped, running `build.sh` again skips the packages that are
already built, and Chrome's compile carries on from the files it has already
made.

## 4. Or build from a WSL shell

```bash
cd /mnt/d/chromiumos-pinebook-pro-rk3399
build/linux/preflight.sh
build/linux/sync.sh
build/linux/build.sh
```

## 5. Write the image to microSD

The image ends up in `output\images\chromiumos-pinebook-pro-rk3399-test.bin`,
with U-Boot and the boot script already in it. Write it with
[balenaEtcher](https://etcher.balena.io/) or [Rufus](https://rufus.ie/);
everything on the card is erased. Copy `google-api-keys.txt` off the card
first if you use one: [USER_GUIDE.md](USER_GUIDE.md#before-writing-a-new-image-to-a-card-you-already-use).

WSL2 does not see USB card readers by default. To use
`build/linux/flash-microsd.sh` from WSL, attach the reader first with
[usbipd-win](https://github.com/dorssel/usbipd-win)
(`usbipd list`, `usbipd bind --busid <id>`, `usbipd attach --wsl --busid <id>`).

The next steps, from the first boot to the logs, are in
[USER_GUIDE.md](USER_GUIDE.md). Moving the system from the card to the eMMC
or an NVMe SSD is done on the laptop, in the Pinebook app:
[INSTALL_TO_EMMC_NVME.md](INSTALL_TO_EMMC_NVME.md).

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `$'\r': command not found` | scripts have CRLF endings; see section 2 |
| `... is on a Windows drive` | set `-ChromiumOSRoot` / `CHROMIUMOS_ROOT` to a path inside WSL |
| build killed, out of memory | raise `memory=` and `swap=` in `.wslconfig`, `wsl --shutdown` |
| `mcopy is missing` or `sfdisk is missing` | `sudo apt install mtools fdisk` in the distro |
| the build got very slow after a few hours | the CPU is throttling; see [Long builds on a laptop](#long-builds-on-a-laptop) |
| anything else | the full log is in `output\logs\` |
