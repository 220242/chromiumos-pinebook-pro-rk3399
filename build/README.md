# Build scripts

These scripts run the standard ChromiumOS flow for the board named in
`boards/pinebook-pro-rk3399/board.conf` (`BOARD_NAME`): fetch the source with
`repo`, create the SDK (`cros_sdk`), `setup_board`, `build_packages`,
`build_image`, then put the boot loader into the image and copy it out. A
`patch` stage rebuilds a few packages and installs them into the last image in
minutes, which is how most changes are tested.

They run on an x86_64 Linux machine or in WSL2 on Windows, with Python 3.11
or newer (on Ubuntu 22.04, `sudo apt install python3.11`; the scripts use it
when the default `python3` is older). On Windows, see
[docs/WINDOWS_BUILD.md](../docs/WINDOWS_BUILD.md).

```
build/
├── linux/
│   ├── common.sh              shared settings and helpers (sourced, not run)
│   ├── preflight.sh           checks the machine; changes nothing
│   ├── sync.sh                depot_tools + repo init + repo sync
│   ├── build.sh               the stages below
│   ├── patch-image-inner.sh   runs inside the SDK for the patch stage
│   └── flash-microsd.sh       writes the image to a microSD card (Linux only)
└── windows/
    └── Start-PinebookBuild.ps1   runs preflight/sync/build inside WSL2
```

## First build

```bash
git clone https://github.com/220242/chromiumos-pinebook-pro-rk3399.git
cd chromiumos-pinebook-pro-rk3399

build/linux/preflight.sh          # disk, RAM, tools, network, filesystem
build/linux/sync.sh               # ~/depot_tools and ~/chromiumos (tens of GB)
build/linux/build.sh              # overlay sdk board packages image
build/linux/flash-microsd.sh /dev/sdX
```

The first `build.sh` is long: the SDK download, every package, and Chrome
compiled from source (see [Chrome](#chrome-from-source)), which alone takes
many hours. Later builds reuse what is already built.

## Stages

`build.sh` with no arguments runs `overlay sdk board packages image`. Name
stages to run only those, in the order given.

| Stage      | What it does |
|------------|--------------|
| `overlay`  | Copies `boards/<board>/overlay-<board>/` to `~/chromiumos/src/overlays/overlay-<board>/` with `rsync --delete` (copied, not symlinked: the SDK only sees files inside the checkout). Refuses files with CRLF line endings. |
| `sdk`      | `cros_sdk --create`: downloads the SDK the first time, updates it later. |
| `board`    | `setup_board --board=<board>`. |
| `packages` | `cros build-packages --board=<board>`. |
| `image`    | `cros build-image --board=<board> --no-enable-rootfs-verification <type>`, then `export`. |
| `export`   | Copies the last built image to `OUTPUT_DIR/images/`, writes U-Boot at sector 64 and copies `boot.scr` and `pinebook-collect.sh` to EFI-SYSTEM (`boards/pinebook-pro-rk3399/install-u-boot.sh`), and writes a `.sha256`. The image is prepared on the Linux file system and copied out once. |
| `patch`    | Rebuilds the packages in `PATCH_PACKAGES` (`emerge-<board> --usepkg`), installs them into the root file system of the last built image as `build_image` would, relabels it for SELinux, keeps the image's `/etc/lsb-release`, then runs `export`. |

The image is always built with rootfs verification off: there is no verified
boot on this board and the boot script mounts ROOT-A read-only by PARTUUID.

## Which build for which change

Most changes do not need `build_image` (about 50 minutes on the project's
PC) or a full `build_packages`.

| Changed | Run |
|---------|-----|
| A package in the overlay (its ebuild or `files/`), e.g. the Pinebook app | Bump the ebuild revision (`-rN` in the file name), then `PATCH_PACKAGES="chromeos-base/pinebook-control" build/linux/build.sh overlay patch` |
| Several packages, or a package the image did not have yet | List every one of them in `PATCH_PACKAGES`: the patch stage installs exactly those atoms (`--nodeps`), not their new dependencies |
| `kernel/pinebook-pro.config` | Rebuild the kernel explicitly, because Portage does not notice a changed fragment: `cros_sdk -- emerge-pinebook-pro-rk3399 sys-kernel/chromeos-kernel-6_6`, then `PATCH_PACKAGES=sys-kernel/chromeos-kernel-6_6 build/linux/build.sh overlay patch` |
| `scripts/disk_layout.json`, `profiles/base/make.defaults` USE flags that many packages read, or anything that should start from a clean image | `build/linux/build.sh overlay packages image` |
| Only the exported copy is missing or was deleted | `build/linux/build.sh export` |

On the project's PC the packages and the image patch take 2 to 7 minutes,
and exporting the 7.9 GB image to the Windows drive about 6 more (11 minutes
in all for three small packages).

Things to know about `patch`:

- It modifies the last image `build_image` made
  (`~/chromiumos/src/build/images/<board>/latest/`) in place, so patches add
  up. The next `image` stage starts again from the packages.
- `--usepkg` reuses a binary package with the same version. Without a new
  revision a changed ebuild or file may not be rebuilt.
- From Windows: `-Stage overlay,patch -Package chromeos-base/pinebook-control`.

## Chrome from source

`profiles/base/package.use` builds `chromeos-base/chromeos-chrome` with
`chrome_media` (H.264, AAC, MP3, MP4 and other proprietary codecs and
containers), `hevc_codec`, `subpixel_rendering`, and without tests or debug
information. Google's prebuilt Chromium for this ChromiumOS version has none
of the codecs, so YouTube live streams (H.264 with AAC) cannot play with it.
No prebuilt package matches these flags, so `build_packages` (or a `patch`
run with `chromeos-base/chromeos-chrome`) compiles Chrome:

- about 21 GB of Chromium source in the SDK's cache and about 78,000 build
  steps; more than a day on the project's laptop CPU (i7-9750H) when it
  throttles under load, so keep the charger in and Windows on its highest
  performance power mode;
- later builds are incremental until a sync brings a new Chrome version.

Codecs that only Google's own builds have (Widevine DRM for Netflix and the
like) are not part of any source build.

To build with the prebuilt Chromium instead (fast, but no H.264, AAC or
HEVC), delete the `chromeos-base/chromeos-chrome` line from
`profiles/base/package.use`.

ROOT-A is 2 GiB and had about 700 MB free with the prebuilt Chrome. If a
bigger Chrome does not fit, grow partition 3 in `scripts/disk_layout.json`
and run a full `packages image`.

## Settings

All are environment variables and all are optional.

| Variable          | Default | Meaning |
|-------------------|---------|---------|
| `BOARD`           | `BOARD_NAME` from board.conf | board to build |
| `CHROMIUMOS_ROOT` | `~/chromiumos` | ChromiumOS checkout; must be on a Linux file system |
| `DEPOT_TOOLS`     | `~/depot_tools` | depot_tools checkout (provides `repo` and `cros_sdk`) |
| `MANIFEST_BRANCH` | `stable` | manifest branch: `stable` is the newest `main` snapshot that has prebuilt binary packages; `main` or a release branch such as `release-R130-16033.B` also work |
| `MANIFEST_URL`    | chromiumos/manifest | manifest repository |
| `IMAGE_TYPE`      | `test` | `base`, `dev` or `test`; the Pinebook tools and docs assume `test` (VT2 login, `sudo`) |
| `OUTPUT_DIR`      | `<repo>/output` | images (`images/`) and logs (`logs/`) |
| `JOBS`            | `nproc` | parallel jobs for `repo sync` and the patch stage's `emerge` |
| `PATCH_PACKAGES`  | none | packages for the `patch` stage |
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

The `.bin` is ready to write to a card as it is: U-Boot is at sector 64 and
EFI-SYSTEM (partition 12) has `boot.scr` and `pinebook-collect.sh`, with the
partition type set to Basic data so Windows can open it. A new export
replaces the previous image; copy it aside first if you want to keep it.

## Rules the SDK taught us

For anyone changing the overlay; each of these cost a build.

- Ebuilds are **EAPI 7**: the SDK's Portage does not know EAPI 8.
- Every upstart job (`/etc/init/*.conf`) needs an **`oom score`** line, or
  the package fails the SDK's install check (`Missing "oom" clause`).
- Nothing a package installs under **`/var`** reaches the laptop: `/var` is
  on the stateful partition, not in the image. Put fixed files under `/usr`
  and create runtime directories at boot.
- Packages that download sources need a **Manifest committed here**: the
  `overlay` stage copies with `rsync --delete`, so a Manifest generated only in
  the checkout is lost. Tarballs that are not on the ChromeOS mirrors need
  `RESTRICT="mirror"`.
- A board `virtual/chromeos-bsp` must stay above arm64-generic's version;
  `profiles/base/package.mask` makes the build stop instead of silently using
  arm64-generic's when ours cannot be installed.
