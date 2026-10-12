# Copyright 2026 The chromiumos-pinebook-pro-rk3399 Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit appid cros-audio-configs

DESCRIPTION="Pinebook Pro board support: boot script, firmware, audio and the Pinebook app"
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
	chromeos-base/pinebook-control
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
	# On VT2: sudo pinebook-collect (logs and hardware state to FAT).
	dosbin "${FILESDIR}/pinebook-collect"
	insinto /etc/init
	doins "${FILESDIR}/pinebook-boot-logs.conf"

	# Bring-up: run chromeos_startup under strace by installing
	# files/startup.override (not installed now that it boots; the TPM fix
	# came from such a trace).
	dosbin "${FILESDIR}/pinebook-startup-trace"

	# Sound: UCM for the ES8316 codec (card "rockchip,es8316-codec"), which
	# CRAS needs to use the speakers, the headphone jack and the microphone.
	install_audio_configs pinebook-pro-rk3399 "${FILESDIR}/audio-config"
}
