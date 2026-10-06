# Build scripts

These scripts run the standard ChromiumOS flow for the board named in
`boards/pinebook-pro-rk3399/board.conf` (`BOARD_NAME`):
fetch the source with `repo`, enter `cros_sdk`, `setup_board`,
`build_packages`, `build_image`, then write the image to a microSD card.

They run on an x86_64 Linux machine or in WSL2 on Windows, with Python 3.11
or newer (on Ubuntu 22.04, `sudo apt install python3.11`; the scripts use it
when the default `python3` is older).
On Windows, see [docs/WINDOWS_BUILD.md](../docs/WINDOWS_BUILD.md).

```
build/
├── linux/
│   ├── common.sh          shared settings and helpers (sourced, not run)
│   ├── preflight.sh       checks the machine; changes nothing
│   ├── sync.sh            depot_tools + repo init + repo sync
│   ├── build.sh           overlay, cros_sdk, setup_board, build-packages, build-image
│   └── flash-microsd.sh   writes the image to a microSD card (Linux only)
└── windows/
    └── Start-PinebookBuild.ps1   runs preflight/sync/build inside WSL2
```

## Quick start (Linux or a WSL2 shell)

```bash
git clone https://github.com/220242/chromiumos-pinebook-pro-rk3399.git
cd chromiumos-pinebook-pro-rk3399

build/linux/preflight.sh          # disk, RAM, tools, network, filesystem
build/linux/sync.sh               # ~/depot_tools and ~/chromiumos
build/linux/build.sh              # all stages, test image
build/linux/flash-microsd.sh /dev/sdX
```

`build.sh` runs these stages in order; name some of them to run only those:

| Stage      | What it runs |
|------------|--------------|
| `overlay`  | copies `boards/<board>/overlay-<board>/` to `~/chromiumos/src/overlays/overlay-<board>/` |
| `sdk`      | `cros_sdk --create` (downloads the SDK the first time) |
| `board`    | `cros_sdk -- setup_board --board=<board>` |
| `packages` | `cros_sdk -- cros build-packages --board=<board>` |
| `image`    | `cros_sdk -- cros build-image --board=<board> --no-enable-rootfs-verification <type>`, then copies the image to `output/images/` |

```bash
build/linux/build.sh packages image   # rebuild after changing packages
```

The overlay is copied rather than symlinked because the SDK chroot only sees
files inside the ChromiumOS checkout.

## Settings

All are environment variables and all are optional.

| Variable          | Default | Meaning |
|-------------------|---------|---------|
| `BOARD`           | `BOARD_NAME` from board.conf | board to build |
| `CHROMIUMOS_ROOT` | `~/chromiumos` | ChromiumOS checkout; must be on a Linux filesystem |
| `DEPOT_TOOLS`     | `~/depot_tools` | depot_tools checkout (provides `repo` and `cros_sdk`) |
| `MANIFEST_BRANCH` | `main` | manifest branch, e.g. `release-R130-16033.B` |
| `MANIFEST_URL`    | chromiumos/manifest | manifest repository |
| `IMAGE_TYPE`      | `test` | `base`, `dev` or `test` |
| `OUTPUT_DIR`      | `<repo>/output` | images (`images/`) and logs (`logs/`) |
| `JOBS`            | `nproc` | parallel `repo sync` jobs |
| `DRY_RUN`         | `0` | `1` prints the commands without running them |

Example: `IMAGE_TYPE=dev MANIFEST_BRANCH=release-R130-16033.B build/linux/sync.sh`.

Every run of `sync.sh` and `build.sh` writes a log to `output/logs/`.

## Output

```
output/
├── images/
│   ├── chromiumos-pinebook-pro-rk3399-test.bin
│   └── chromiumos-pinebook-pro-rk3399-test.bin.sha256
└── logs/
    ├── sync-YYYYMMDD-HHMMSS.log
    └── build-YYYYMMDD-HHMMSS.log
```

## What a bootable image needs

The scripts are the standard flow; the board support comes from the overlay.

- **Board overlay.** The `overlay` stage copies
  `boards/pinebook-pro-rk3399/overlay-pinebook-pro-rk3399/`. Without that
  directory it stops, and `setup_board` cannot find the board. See
  [docs/PORTING_GUIDE.md](../docs/PORTING_GUIDE.md).
  To try the toolchain and SDK without it, build a generic board:
  `BOARD=arm64-generic build/linux/build.sh sdk board packages image`
  (from Windows: `-Board arm64-generic -Stage sdk,board,packages,image`).
- **Bootloader.** ChromiumOS ARM images do not carry U-Boot. The Pinebook Pro
  needs U-Boot in SPI flash or at the start of the card, plus a way for it to
  load the ChromiumOS kernel. That belongs in the overlay.
