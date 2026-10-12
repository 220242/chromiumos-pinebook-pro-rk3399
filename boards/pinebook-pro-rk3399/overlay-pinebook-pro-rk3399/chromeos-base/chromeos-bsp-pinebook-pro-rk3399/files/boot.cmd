# U-Boot script that boots ChromiumOS on the Pinebook Pro.
#
# U-Boot's bootcmd (sys-boot/pinebook-pro-u-boot, files/chromiumos.config)
# loads this script from /boot/pinebook-pro/boot.scr on ROOT-A (partition 3)
# and sets devtype/devnum to the disk it came from (mmc 1 = microSD,
# mmc 0 = eMMC). The kernel Image and device tree are installed next to it by
# the board's profile.bashrc hook on the ChromeOS kernel package.
#
# Only ROOT-A is booted, and the image must be built with
# --no-enable-rootfs-verification: there is no verified boot or A/B
# switching on this board yet.

setenv cros_part 3
part uuid ${devtype} ${devnum}:${cros_part} cros_root_uuid

load ${devtype} ${devnum}:${cros_part} ${kernel_addr_r} /boot/pinebook-pro/Image
load ${devtype} ${devnum}:${cros_part} ${fdt_addr_r} /boot/pinebook-pro/rk3399-pinebook-pro.dtb

# The ChromeOS kernel's Panfrost only binds to "arm,mali-t860-CHROMIUM" (the
# plain compatibles are left to ARM's driver, which this board does not use).
# Without the GPU driver Chrome cannot start and the boot logo stays.
fdt addr ${fdt_addr_r}
fdt resize 1024
fdt set /gpu@ff9a0000 compatible "rockchip,rk3399-mali" "arm,mali-t860-CHROMIUM"

# Bring-up: a task stuck for 30 s is reported (with its stack) instead of
# panicking and rebooting after 120 s, so pinebook-boot-logs can save it.
# printk.devkmsg=on: keep every message programs write to the kernel log;
# by default most of chromeos_startup's were dropped by the rate limit.
# brcmfmac.feature_disable=0x82000: no firmware supplicant (FWSUP, 0x2000)
# and no SAE in firmware (0x80000). With them the AP6256 firmware takes over
# the WPA handshake and ChromeOS's wpa_supplicant fails to connect
# ("disconnect-failure"); the same setting is the usual fix on other
# BCM4345 boards.
setenv bootargs "console=ttyS2,1500000 console=tty1 root=PARTUUID=${cros_root_uuid} rootwait ro noinitrd cros_legacy cros_debug loglevel=7 hung_task_panic=0 hung_task_timeout_secs=30 printk.devkmsg=on brcmfmac.feature_disable=0x82000"
booti ${kernel_addr_r} - ${fdt_addr_r}
