# Android apps (Waydroid)

The image includes [Waydroid](https://waydro.id): Android (LineageOS 20,
Android 13) runs in a container on the ChromiumOS kernel, and each Android app
opens in its own window on the ChromiumOS desktop. Everything is set up and
controlled from one page, http://android.localhost, or from the `android`
command in a shell.

**Status:** the image builds with it, but it has not run on the Pinebook Pro
yet (the image does not reach the login screen yet). See "What was checked"
and "Not verified yet" below.

## Using it

1. Log in. The service behind the page runs while someone is logged in.
2. Open **http://android.localhost** in Chrome.
3. The first time, press **Set up Android**. Tick **With Google Play** first if
   you want Play (see below). Setting up:
   - adds an `ANDROID-DATA` partition in the free space at the end of the
     microSD card (ChromiumOS's partitions are not changed);
   - downloads Android, about 1 GB;
   - starts Android and opens its window.

   This takes 10 to 30 minutes; the page shows each step and the download
   progress, and the laptop can be used meanwhile. If the download fails,
   pressing the button again continues: images already downloaded are kept.
4. After that the page has:
   - **Open Android** (or **Start Android**): Android's home screen in a window;
   - the installed apps: a click opens one app in its own window;
   - **Install APK…**, or drop an `.apk` file on the page. If Android is
     stopped, it is started first;
   - **Stop**;
   - **Open Android when this page opens**;
   - **Log**: the service's recent log.
5. **Install as an app** (the button in the page header, or Chrome's menu)
   puts the page in the launcher and on the shelf like any other app.

Android stops when you log out and starts again from the page or the command.

### From a shell

The `android` command does the same from crosh's `shell` or from VT2 (log in
as `chronos`). It needs no root.

| Command | What it does |
|---------|--------------|
| `android` | Set up on first use (asks first; `-y` does not), start, show Android |
| `android --play` | The same with Google Play; on an Android without Play it adds Play |
| `android stop` | Stop Android |
| `android status [--json]` | What Android is doing, and the last error |
| `android apps [-a]` | Installed apps (`-a` also Android's own) |
| `android launch PACKAGE` | Open one app, starting Android if needed |
| `android install FILE.apk` | Install an APK |
| `android play-id` | The device ID to register for Google Play |
| `android log` | The service's recent log |

## The ANDROID-DATA partition

Android's system images and its data (apps, their files, settings) are on a
partition of their own, mounted at `/var/lib/waydroid`. The stateful partition
is too small for them and mounted `noexec`.

- It is created on the microSD card the system booted from, after the image's
  last partition, in all the free space that is left: write the image to a
  card of 16 GB or more. At least 4 GB must be free.
- Only a GPT entry is added (partition 13, ext4, label `ANDROID-DATA`) and the
  backup GPT is moved to the end of the card. The ChromiumOS partitions stay
  as they are.
- It is never created on the eMMC: when the system runs from the eMMC, the page
  says so and does nothing.
- Writing a new image of the **same size** to the card keeps Android and its
  apps: the partition's file system is still there after the image. The page
  then offers to use it, and **Set up Android** only adds the partition back
  and starts Android, without downloading it again. An image of a different
  size moves the partition's start, and Android is set up from scratch.
- Everyone who logs in on the laptop shares the same Android.

## Google Play

Google Play comes with Waydroid's GAPPS image. Tick **With Google Play** before
setting up, or later press **Add Google Play** (`android --play`): the system
image is downloaded again, apps and data stay.

Google only lets Play work on a registered device:

1. Start Android once with Play and wait until it has started.
2. Press **Show the device ID** (`android play-id`).
3. Enter it at https://www.google.com/android/uncertified, signed in with the
   Google account you use in Play.
4. Stop and start Android. It can take a while before Play accepts the device.

## Logs

- `/var/log/pinebook-android.log`: the service, including Waydroid's output
  (the page's **Log** shows the recent part; `android log` too).
- `logs\boot-NNNN\run_pinebook-android.log.txt` on the card's FAT partition
  (`EFI-SYSTEM`), readable from Windows; copied there by `pinebook-boot-logs`.
- `/var/lib/waydroid/waydroid.log`: Waydroid's own log.

## How it works

- **Kernel** (`kernel/pinebook-pro.config`): binder IPC on binderfs, PSI,
  the namespaces and freezer cgroup LXC uses, veth, a bridge with NAT for the
  container's network, overlayfs, loop devices, FUSE, `sw_sync` (with debugfs)
  and DMA-BUF heaps. All built in.
- **Packages** in the board overlay: `app-containers/lxc` (7.0.0),
  `app-containers/waydroid` (1.6.3), `dev-libs/libglibutil`, `dev-libs/gbinder`,
  `dev-python/gbinder` and `chromeos-base/pinebook-waydroid` (the service, the
  page and the command). `virtual/chromeos-bsp` pulls them in when the
  `waydroid` USE flag is set, which `profiles/base/make.defaults` does.
- **No PyGObject.** Waydroid imports GLib through PyGObject, which needs GObject
  introspection, and ChromiumOS does not build that for its boards. The
  Waydroid package installs a small `gi` package next to Waydroid instead
  (`app-containers/waydroid/files/gi`): GLib's main loop, signal, idle and
  timeout sources through `ctypes` (the same main context dbus-python and
  libgbinder use), and `KeyFile` for the apps' `.desktop` files in plain
  Python.
- **Waydroid's configs** are adjusted at build time: no AppArmor or seccomp
  lines (LXC here is built without both), so Android also does not get
  `CAP_SYS_TIME`, and the iptables `CHECKSUM` rule may fail without stopping
  the network.
- **The service** (`pinebook-android`, an upstart job) starts when someone logs
  in and stops on logout. It runs as root and:
  - mounts `ANDROID-DATA` (creating it on first setup) at `/var/lib/waydroid`;
  - runs `waydroid init` for the download, and `waydroid container start`;
  - starts a D-Bus session bus as `chronos` (ChromiumOS has none), then
    `waydroid session start` as `chronos`, on Chrome's Wayland server
    (`/run/chrome/wayland-0`), so Android's windows are ChromeOS windows;
  - points Waydroid at Panfrost's render node and turns Vulkan off (Mesa has
    no Vulkan driver for the Mali-T860);
  - serves the page and its API on `127.0.0.1:80`. Chrome resolves
    `*.localhost` to the loopback address, and the page counts as a secure
    origin, so it can be installed as an app. The API answers only with a
    localhost `Host` header, and changes need the `X-Android-Launcher` header
    and a matching `Origin`, so other web pages cannot use it.
- Android's session data lives under `/var/lib/waydroid/user` on `ANDROID-DATA`,
  not in a user's home.

## What was checked

In the ChromiumOS SDK (stable branch): the kernel and every package build, and
`build_image` makes the image. Its root partition has Waydroid, LXC and the
`pinebook-android` job, the kernel has binder and binderfs built in, and about
750 MB of the root partition's 2 GB is left. Python is in the root partition
now; if it runs out of space, grow ROOT-A in `scripts/disk_layout.json`.

In a cloud container, without a ChromiumOS checkout or the hardware:

- The kernel fragment merges onto the board config with
  `kernel/apply-fragment.sh` (no symbol dropped) and the kernel builds with it.
- libglibutil, libgbinder and its Python module build the way the ebuilds
  build them; the module imports. The Waydroid ebuild's config changes apply.
  The ebuilds' Manifests hold the hashes of the real source tarballs.
- The `gi` stand-in runs Waydroid 1.6.3's own D-Bus and main loop code
  (container and session services, signals, threads); its `KeyFile` writes
  the same `.desktop` files as GLib's.
- Partitioning, on card images with the real disk layout: ANDROID-DATA is
  added after the image, the backup GPT moves, the eMMC is refused, and
  rewriting the same image keeps the data.
- The page (in Chromium, Russian and English) and the `android` command
  against the service with a stand-in for Waydroid: setup with download
  progress, start, the app list, APK install (also while stopped), a file
  that is not an APK, Google Play's device ID, stop.

## Not verified yet

These need the image on the laptop:

- **SELinux.** ChromiumOS enforces it; the policy may deny binder, LXC or the
  container's mounts. On the test image, `sudo setenforce 0` in a shell tells
  whether that is the cause; the log then shows what to allow.
- **Graphics.** Android's Mesa on Panfrost through Chrome's Wayland server
  (Exo): which buffer formats and protocols Exo accepts from Waydroid.
- **Network.** The container's NAT bridge next to ChromeOS's own firewall rules
  (patchpanel).
- **Memory.** Android takes about 1 to 1.5 GB of the 4 GB.

Not there at all: sound (ChromeOS has no PulseAudio, which Waydroid uses), the
camera, and clipboard sharing.

## Building

The kernel config changed, so a full build is needed (`build_packages`, then
`build_image`); the quick package patch does not cover the kernel. Portage
does not rebuild the kernel when only `kernel/pinebook-pro.config` changes (the
kernel's ebuild stays the same), so rebuild it explicitly:

```bash
emerge-pinebook-pro-rk3399 sys-kernel/chromeos-kernel-6_6
```

To check that every package Android needs can be installed, in a minute and
without building anything:

```bash
emerge-pinebook-pro-rk3399 -pv chromeos-base/pinebook-waydroid
```

The ebuilds are EAPI 7: the SDK's Portage has no EAPI 8. If one of them cannot
be installed, the build stops (`profiles/base/package.mask` keeps
arm64-generic's `virtual/chromeos-bsp` from standing in for the board's).

To build an image without Waydroid, remove the `USE="${USE} waydroid"` line
from `profiles/base/make.defaults`; the kernel options do no harm without it.
