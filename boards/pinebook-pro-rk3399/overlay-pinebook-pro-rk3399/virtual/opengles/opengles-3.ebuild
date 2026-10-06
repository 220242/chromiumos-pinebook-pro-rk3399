# Copyright 2026 The chromiumos-pinebook-pro-rk3399 Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

DESCRIPTION="Virtual for OpenGLES implementations: Mesa Panfrost for the Mali-T860"
HOMEPAGE="https://github.com/220242/chromiumos-pinebook-pro-rk3399"

LICENSE="metapackage"
SLOT="0"
KEYWORDS="*"

# Version 3 so it wins over chromiumos-overlay's and arm64-generic's versions.
DEPEND="media-libs/mesa-panfrost"
RDEPEND="${DEPEND}"
