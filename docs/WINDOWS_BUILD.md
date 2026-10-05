# Building on Windows 11 with WSL2

ChromiumOS only builds on x86_64 Linux. On Windows the build runs inside WSL2,
using the same scripts as on Linux (`build/linux/*.sh`, described in
[build/README.md](../build/README.md)). `build/windows/Start-PinebookBuild.ps1`
starts them from PowerShell.

## 1. Prepare WSL2

```powershell
wsl --install -d Ubuntu-22.04
wsl --set-default-version 2
wsl -l -v            # VERSION must be 2
```

Give WSL enough memory. Create `%UserProfile%\.wslconfig`:

```ini
[wsl2]
memory=16GB
swap=16GB
```

Then run `wsl --shutdown` so it takes effect. The WSL virtual disk grows on
demand; the drive that holds it (usually C:) needs about 200 GB free.

Inside Ubuntu, install the host tools and set a git identity (`repo` needs it):

```bash
sudo apt update
sudo apt install -y git curl xz-utils python3 rsync
git config --global user.name  "Your Name"
git config --global user.email "you@example.com"
```

## 2. Where the files live

| What | Where | Why |
|------|-------|-----|
| ChromiumOS checkout | `~/chromiumos` inside WSL | must be on the Linux filesystem; `/mnt/c`, `/mnt/d` are slow, case-insensitive and rejected by the scripts |
| depot_tools | `~/depot_tools` inside WSL | |
| This repository | anywhere, e.g. `D:\chromiumos-pinebook-pro-rk3399` | small; can stay on Windows |
| Finished image and logs | `<this repo>\output\` | readable from Windows for flashing |

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
.\build\windows\Start-PinebookBuild.ps1 -Distro Ubuntu-22.04 -ImageType dev
.\build\windows\Start-PinebookBuild.ps1 -ManifestBranch release-R130-16033.B
.\build\windows\Start-PinebookBuild.ps1 -DryRun                  # print commands only
```

`Get-Help .\build\windows\Start-PinebookBuild.ps1 -Full` lists all of them.
`cros_sdk` asks for your Linux sudo password in the same window.

## 4. Or build from a WSL shell

```bash
cd /mnt/d/chromiumos-pinebook-pro-rk3399
build/linux/preflight.sh
build/linux/sync.sh
build/linux/build.sh
```

## 5. Write the image to microSD

The image ends up in `output\images\chromiumos-pinebook-pro-rk3399-test.bin`.

From Windows, write it with [balenaEtcher](https://etcher.balena.io/),
[Rufus](https://rufus.ie/) (DD mode) or Raspberry Pi Imager ("Use custom").
Everything on the card is erased.

WSL2 does not see USB card readers by default. To use
`build/linux/flash-microsd.sh` from WSL, attach the reader first with
[usbipd-win](https://github.com/dorssel/usbipd-win)
(`usbipd list`, `usbipd bind --busid <id>`, `usbipd attach --wsl --busid <id>`).

## 6. Installing to eMMC or NVMe

Boot the microSD card first. ChromiumOS installs itself to another disk with
`chromeos-install` from a root shell (VT2 or SSH on a test image), e.g.
`chromeos-install --dst /dev/mmcblk2`. See
[INSTALL_TO_EMMC_NVME.md](INSTALL_TO_EMMC_NVME.md).

## Known gaps

The board is not ported yet: there is no board overlay and no U-Boot setup, so
`setup_board` fails for `pinebook-pro-rk3399` and a built image would not boot
on its own. Details are in [build/README.md](../build/README.md#what-is-still-missing-before-an-image-boots).

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `$'\r': command not found` | scripts have CRLF endings; see section 2 |
| `... is on a Windows drive` | set `-ChromiumOSRoot` / `CHROMIUMOS_ROOT` to a path inside WSL |
| build killed, out of memory | raise `memory=` and `swap=` in `.wslconfig`, `wsl --shutdown` |
| `No board overlay for pinebook-pro-rk3399` | expected until the overlay is written; see Known gaps |
| anything else | the full log is in `output\logs\` |
