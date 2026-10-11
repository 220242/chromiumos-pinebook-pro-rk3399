# Copyright 2022-2026 Gentoo Authors
# Copyright 2026 The chromiumos-pinebook-pro-rk3399 Authors
# Distributed under the terms of the GNU General Public License v2
# Adapted from ::guru dev-libs/gbinder: EAPI 7 (the SDK's Portage has no
# EAPI 8), ChromeOS keywords, no tools.

EAPI=7

inherit toolchain-funcs

MY_P="lib${P}"

DESCRIPTION="GLib-style interface to binder"
HOMEPAGE="https://github.com/mer-hybris/libgbinder"
SRC_URI="https://github.com/mer-hybris/libgbinder/archive/${PV}.tar.gz -> ${P}.tar.gz"
S="${WORKDIR}/${MY_P}"

LICENSE="BSD"
SLOT="0/${PV}"
KEYWORDS="*"
# mirror: not on the ChromeOS mirrors, fetch from SRC_URI despite force-mirror.
RESTRICT="mirror"

DEPEND="
	dev-libs/glib:2
	dev-libs/libglibutil
"
RDEPEND="${DEPEND}"
BDEPEND="virtual/pkgconfig"

PATCHES=(
	"${FILESDIR}/${P}-respect-env.patch"
)

src_configure() {
	tc-export AR CC PKG_CONFIG RANLIB STRIP
	export KEEP_SYMBOLS=1
	export LIBDIR="${EPREFIX}/usr/$(get_libdir)"
}

src_compile() {
	emake release pkgconfig
}

src_install() {
	emake DESTDIR="${D}" \
		INSTALL_INCLUDE_DIR="${ED}/usr/include/gbinder" \
		install-dev
}
