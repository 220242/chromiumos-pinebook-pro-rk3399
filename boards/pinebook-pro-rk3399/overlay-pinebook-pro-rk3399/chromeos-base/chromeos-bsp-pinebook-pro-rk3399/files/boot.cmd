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

# After pinebook-migrate moved the system off this card, its EFI-SYSTEM
# (partition 12 = 0xc) has pinebook-boot-emmc or pinebook-boot-nvme: boot the
# copy there instead (U-Boot tries the card first). Delete the file to boot
# the card again. The other disk's boot.scr is loaded at pxefile_addr_r
# (scriptaddr still holds this one) and does not chain again.
if test -z "${pxefile_addr_r}"; then setenv pxefile_addr_r 0x00600000; fi
if test "${pinebook_chained}" != "1"; then
	setenv pinebook_chained 1
	setenv pb_devtype ${devtype}
	setenv pb_devnum ${devnum}
	if load ${devtype} ${devnum}:c ${pxefile_addr_r} pinebook-boot-emmc; then
		if load mmc 0:3 ${pxefile_addr_r} /boot/pinebook-pro/boot.scr; then
			echo "pinebook: the system was moved to the eMMC; booting it"
			setenv devtype mmc
			setenv devnum 0
			source ${pxefile_addr_r}
		fi
	fi
	if load ${pb_devtype} ${pb_devnum}:c ${pxefile_addr_r} pinebook-boot-nvme; then
		pci enum
		nvme scan
		if load nvme 0:3 ${pxefile_addr_r} /boot/pinebook-pro/boot.scr; then
			echo "pinebook: the system was moved to the NVMe SSD; booting it"
			setenv devtype nvme
			setenv devnum 0
			source ${pxefile_addr_r}
		fi
	fi
	# The copy did not boot: carry on from this disk.
	setenv devtype ${pb_devtype}
	setenv devnum ${pb_devnum}
fi

setenv cros_part 3
part uuid ${devtype} ${devnum}:${cros_part} cros_root_uuid

load ${devtype} ${devnum}:${cros_part} ${kernel_addr_r} /boot/pinebook-pro/Image
load ${devtype} ${devnum}:${cros_part} ${fdt_addr_r} /boot/pinebook-pro/rk3399-pinebook-pro.dtb

# The ChromeOS kernel's Panfrost only binds to "arm,mali-t860-CHROMIUM" (the
# plain compatibles are left to ARM's driver, which this board does not use).
# Without the GPU driver Chrome cannot start and the boot logo stays.
fdt addr ${fdt_addr_r}
fdt resize 8192
fdt set /gpu@ff9a0000 compatible "rockchip,rk3399-mali" "arm,mali-t860-CHROMIUM"

# CPU overclock / undervolt from the Pinebook app: it writes
# pinebook-tune.scr (fdt commands for the OPP tables) to EFI-SYSTEM
# (partition 12 = 0xc). Delete that file, from any computer, to boot with the
# stock frequencies and voltages again. Loaded at ramdisk_addr_r: there is no
# initrd, and scriptaddr still holds this script.
if load ${devtype} ${devnum}:c ${ramdisk_addr_r} pinebook-tune.scr; then
	echo "Applying pinebook-tune.scr"
	source ${ramdisk_addr_r}
fi

# Bring-up: a task stuck for 30 s is reported (with its stack) instead of
# panicking and rebooting after 120 s, so pinebook-boot-logs can save it.
# loglevel=4: only warnings and errors on the console (the bring-up used 7
# and printk.devkmsg=on, which cost time at every boot; the logs still hold
# everything at the default levels).
# brcmfmac.feature_disable=0x82000: no firmware supplicant (FWSUP, 0x2000)
# and no SAE in firmware (0x80000). With them the AP6256 firmware takes over
# the WPA handshake and ChromeOS's wpa_supplicant fails to connect
# ("disconnect-failure"); the same setting is the usual fix on other
# BCM4345 boards.
setenv bootargs "console=ttyS2,1500000 console=tty1 root=PARTUUID=${cros_root_uuid} rootwait ro noinitrd cros_legacy cros_debug loglevel=4 hung_task_panic=0 hung_task_timeout_secs=30 brcmfmac.feature_disable=0x82000"

# The Pinebook app asked to move the system to another disk: the upstart job
# pinebook-migrate does it at this boot, before the stateful partition is
# mounted. On other boots it exits at once.
if load ${devtype} ${devnum}:c ${ramdisk_addr_r} pinebook-migrate.json; then
	setenv bootargs "${bootargs} pinebook.migrate=1"
fi

booti ${kernel_addr_r} - ${fdt_addr_r}
