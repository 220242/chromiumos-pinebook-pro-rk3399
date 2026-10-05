# Copyright 2026 The chromiumos-pinebook-pro-rk3399 Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

DESCRIPTION="Pinebook Pro board support: U-Boot boot script and firmware"
HOMEPAGE="https://github.com/220242/chromiumos-pinebook-pro-rk3399"

LICENSE="BSD-Google"
SLOT="0"
KEYWORDS="*"

S="${WORKDIR}"

# U-Boot only goes into the board sysroot (/build/<board>/firmware), where
# install-u-boot.sh picks it up; it is not part of the rootfs.
DEPEND="sys-boot/pinebook-pro-u-boot"
RDEPEND="sys-firmware/ap6256-firmware"
BDEPEND="dev-embedded/u-boot-tools"

src_compile() {
	mkimage -A arm64 -O linux -T script -C none -n "ChromiumOS Pinebook Pro" \
		-d "${FILESDIR}/boot.cmd" boot.scr || die
}

src_install() {
	insinto /boot/pinebook-pro
	doins boot.scr
}
