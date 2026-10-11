# Copyright 2022-2026 Gentoo Authors
# Copyright 2026 The chromiumos-pinebook-pro-rk3399 Authors
# Distributed under the terms of the GNU General Public License v2
# Adapted from ::guru dev-libs/libglibutil (EAPI 8, ChromeOS keywords).

EAPI=8

inherit toolchain-funcs

DESCRIPTION="Library of glib utilities from the Sailfish OS project"
HOMEPAGE="https://github.com/sailfishos/libglibutil"
SRC_URI="https://github.com/sailfishos/${PN}/archive/${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="BSD"
SLOT="0"
KEYWORDS="*"
# mirror: not on the ChromeOS mirrors, fetch from SRC_URI despite force-mirror.
RESTRICT="mirror"

DEPEND="dev-libs/glib:2"
RDEPEND="${DEPEND}"
BDEPEND="virtual/pkgconfig"

PATCHES=(
	"${FILESDIR}/${P}-respect-env.patch"
)

src_configure() {
	tc-export AR CC PKG_CONFIG STRIP
	export KEEP_SYMBOLS=1
	export LIBDIR="${EPREFIX}/usr/$(get_libdir)"
}

src_compile() {
	emake release pkgconfig
}

src_install() {
	emake DESTDIR="${D}" \
		INSTALL_INCLUDE_DIR="${ED}/usr/include/gutil" \
		install-dev
}
