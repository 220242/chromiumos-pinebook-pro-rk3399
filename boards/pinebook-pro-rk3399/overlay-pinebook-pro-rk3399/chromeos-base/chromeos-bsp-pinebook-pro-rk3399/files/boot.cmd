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

setenv bootargs "console=ttyS2,1500000 console=tty1 root=PARTUUID=${cros_root_uuid} rootwait ro noinitrd cros_legacy cros_debug loglevel=7"
booti ${kernel_addr_r} - ${fdt_addr_r}
