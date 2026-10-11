# Copyright 2026 The chromiumos-pinebook-pro-rk3399 Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit appid

DESCRIPTION="Pinebook Pro board support: U-Boot boot script and firmware"
HOMEPAGE="https://github.com/220242/chromiumos-pinebook-pro-rk3399"

LICENSE="BSD-Google"
SLOT="0"
KEYWORDS="*"

S="${WORKDIR}"

# U-Boot only goes into the board sysroot (/build/<board>/firmware), where
# install-u-boot.sh picks it up; it is not part of the rootfs.
DEPEND="sys-boot/pinebook-pro-u-boot"
# strace: bring-up only, for pinebook-startup-trace.
RDEPEND="
	dev-debug/strace
	sys-firmware/ap6256-firmware
"
BDEPEND="dev-embedded/u-boot-tools"

src_compile() {
	mkimage -A arm64 -O linux -T script -C none -n "ChromiumOS Pinebook Pro" \
		-d "${FILESDIR}/boot.cmd" boot.scr || die
}

src_install() {
	# /etc/lsb-release app ID; build_image (build_dlc) requires one. This board
	# gets no updates from Google's update server, so the ID is our own.
	doappid "{16104C87-50AC-4034-B538-2268F617198E}" "CHROMEBOOK"

	insinto /boot/pinebook-pro
	doins boot.scr

	# Bring-up: every boot's logs go to logs/ on EFI-SYSTEM and FAT USB drives,
	# readable from Windows (install-u-boot.sh gives EFI-SYSTEM the Basic data
	# type).
	dosbin "${FILESDIR}/pinebook-boot-logs"
	insinto /etc/init
	doins "${FILESDIR}/pinebook-boot-logs.conf"

	# Bring-up: chromeos_startup exits with status 1 without logging why; run
	# it under strace (startup.override replaces the exec line of startup.conf).
	dosbin "${FILESDIR}/pinebook-startup-trace"
	doins "${FILESDIR}/startup.override"
}
