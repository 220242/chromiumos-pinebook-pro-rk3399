# Copyright 2026 The chromiumos-pinebook-pro-rk3399 Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit toolchain-funcs

TFA_PV="2.10.0"

DESCRIPTION="Upstream U-Boot (pinebook-pro-rk3399_defconfig) with TF-A BL31 for the Pinebook Pro"
HOMEPAGE="https://www.denx.de/wiki/U-Boot https://www.trustedfirmware.org/projects/tf-a/"
SRC_URI="
	https://github.com/u-boot/u-boot/archive/refs/tags/v${PV}.tar.gz -> u-boot-${PV}.tar.gz
	https://github.com/ARM-software/arm-trusted-firmware/archive/refs/tags/v${TFA_PV}.tar.gz -> arm-trusted-firmware-${TFA_PV}.tar.gz
"

LICENSE="GPL-2 BSD"
SLOT="0"
KEYWORDS="*"
# Bare-metal firmware: no stripping, no host test suite. mirror: the SDK sets
# FEATURES=force-mirror and these tarballs are not on the ChromeOS mirrors,
# so fetch them from SRC_URI.
RESTRICT="mirror strip test"

BDEPEND="
	dev-lang/swig
	dev-python/pyelftools
	sys-apps/dtc
"

S="${WORKDIR}/u-boot-${PV}"
TFA_S="${WORKDIR}/arm-trusted-firmware-${TFA_PV}"

# The RK3399 BL31 includes firmware for the SoC's Cortex-M0 power-management
# core, which needs a bare-metal 32-bit Arm compiler (see toolchain.conf).
M0_CROSS_COMPILE="arm-none-eabi-"

src_prepare() {
	default
	# tools/Makefile calls plain pkg-config, which the SDK refuses; use the
	# HOSTPKG_CONFIG that src_configure and src_compile pass in.
	sed -i 's/\$(shell pkg-config /$(shell $(HOSTPKG_CONFIG) /' tools/Makefile || die
}

src_configure() {
	# U-Boot and TF-A are built with GCC and GNU binutils (the RK3399 M0
	# firmware in TF-A needs arm-none-eabi-gcc), which the SDK blocks unless
	# the ebuild opts in.
	cros_allow_gnu_build_tools
	tc-export BUILD_CC BUILD_PKG_CONFIG
	# Kconfig probes the target compiler, so CROSS_COMPILE is needed here too
	# (the SDK refuses unprefixed gcc and pkg-config).
	local args=( CROSS_COMPILE="${CHOST}-" HOSTCC="${BUILD_CC}"
		HOSTPKG_CONFIG="${BUILD_PKG_CONFIG}" )
	emake -C "${S}" "${args[@]}" pinebook-pro-rk3399_defconfig
	"${S}"/scripts/kconfig/merge_config.sh -m -O "${S}" "${S}"/.config \
		"${FILESDIR}"/chromiumos.config || die
	emake -C "${S}" "${args[@]}" olddefconfig
}

src_compile() {
	local cross="${CHOST}-"

	# Firmware: no sysroot, no board CFLAGS/LDFLAGS.
	unset CFLAGS CXXFLAGS CPPFLAGS LDFLAGS

	# E=0: TF-A v2.10 predates the SDK's GCC 15; don't make its new warnings
	# fatal.
	emake -C "${TFA_S}" \
		CROSS_COMPILE="${cross}" \
		M0_CROSS_COMPILE="${M0_CROSS_COMPILE}" \
		HOSTCC="${BUILD_CC}" \
		E=0 \
		PLAT=rk3399 bl31

	# DTC: use the SDK's dtc and its Python libfdt module instead of building
	# them in tree; the in-tree pylibfdt extension picks up the board's Python
	# settings in the SDK and fails to link. A full path: the dtb rules list
	# $(DTC) as a prerequisite.
	emake -C "${S}" \
		CROSS_COMPILE="${cross}" \
		HOSTCC="${BUILD_CC}" \
		HOSTPKG_CONFIG="${BUILD_PKG_CONFIG}" \
		DTC="$(type -P dtc)" \
		BL31="${TFA_S}/build/rk3399/release/bl31/bl31.elf"
}

src_install() {
	# Sysroot only: install-u-boot.sh reads /build/<board>/firmware.
	insinto /firmware/pinebook-pro
	# u-boot-rockchip.bin = idbloader.img + u-boot.itb, written at sector 64.
	doins u-boot-rockchip.bin idbloader.img u-boot.itb
	# Same loader for the 16 MB SPI NOR flash, written at offset 0.
	doins u-boot-rockchip-spi.bin
}
