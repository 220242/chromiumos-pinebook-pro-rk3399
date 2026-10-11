# Copyright 2022-2026 Gentoo Authors
# Copyright 2026 The chromiumos-pinebook-pro-rk3399 Authors
# Distributed under the terms of the GNU General Public License v2
# Adapted from ::guru dev-python/gbinder: EAPI 7 (the SDK's Portage has no
# EAPI 8), ChromeOS keywords, $PKG_CONFIG for the cross build.

EAPI=7

# A wide range, with unknown ones ignored: the board's Python and the
# eclass's list of implementations depend on the ChromiumOS checkout.
PYTHON_COMPAT=( python3_{8..15} )
PYTHON_COMPAT_NO_STRICT=1
DISTUTILS_USE_PEP517=setuptools
DISTUTILS_EXT=1

inherit distutils-r1 toolchain-funcs

MY_P="${PN}-python-${PV}"

DESCRIPTION="Python bindings for dev-libs/gbinder"
HOMEPAGE="https://github.com/waydroid/gbinder-python"
SRC_URI="https://github.com/waydroid/gbinder-python/archive/${PV}.tar.gz -> ${P}.gh.tar.gz"
S="${WORKDIR}/${MY_P}"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="*"
# mirror: not on the ChromeOS mirrors, fetch from SRC_URI despite force-mirror.
RESTRICT="mirror"

DEPEND="
	>=dev-libs/gbinder-1.1.40
	dev-libs/libglibutil
"
RDEPEND="${DEPEND}"
BDEPEND="
	virtual/pkgconfig
	dev-python/cython[${PYTHON_USEDEP}]
"

PATCHES=(
	"${FILESDIR}/${P}-pkg-config.patch"
)

python_configure_all() {
	tc-export PKG_CONFIG
}
