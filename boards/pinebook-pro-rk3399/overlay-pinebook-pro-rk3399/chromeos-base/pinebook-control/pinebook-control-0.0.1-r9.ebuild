# Copyright 2026 The chromiumos-pinebook-pro-rk3399 Authors
# Distributed under the terms of the GNU General Public License v2

# EAPI 7: the SDK's Portage has no EAPI 8.
EAPI=7

# A wide range, with unknown ones ignored: the board's Python and the
# eclass's list of implementations depend on the ChromiumOS checkout.
PYTHON_COMPAT=( python3_{8..15} )
PYTHON_COMPAT_NO_STRICT=1

inherit python-single-r1

DESCRIPTION="The Pinebook app: hardware monitor, overlay, CPU/GPU limits, overclock and undervolt"
HOMEPAGE="https://github.com/220242/chromiumos-pinebook-pro-rk3399"
S="${WORKDIR}"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="*"
REQUIRED_USE="${PYTHON_REQUIRED_USE}"

# rootdev finds the boot card's EFI-SYSTEM partition; e2fsprogs: e2image,
# resize2fs and dumpe2fs for pinebook-migrate.
RDEPEND="${PYTHON_DEPS}
	sys-apps/rootdev
	sys-fs/e2fsprogs
"

src_install() {
	# The service (root): http://pinebook.localhost:8086 and the saved limits.
	python_scriptinto /usr/sbin
	python_doscript "${FILESDIR}/pinebook-control"
	insinto /etc/init
	doins "${FILESDIR}/pinebook-control.conf"

	# Google API keys for Chrome, from EFI-SYSTEM or the app, before every ui start.
	dosbin "${FILESDIR}/pinebook-chrome-keys"

	# Moving the system to the eMMC or an NVMe SSD (at boot, when asked).
	python_doscript "${FILESDIR}/pinebook-migrate"
	doins "${FILESDIR}/pinebook-chrome-keys.conf"
	doins "${FILESDIR}/pinebook-migrate.conf"

	insinto /usr/share/pinebook-control
	doins -r "${FILESDIR}/web"

	# The app in the launcher from the first login, for every user and for
	# guests: Chrome installs the web apps described in
	# /usr/share/chromium/extensions/web_apps/*.json when a profile loads.
	insinto /usr/share/chromium/extensions/web_apps
	doins "${FILESDIR}/launcher/pinebook-control.json"
	newins "${FILESDIR}/web/icon-192.png" pinebook-control-192.png
	newins "${FILESDIR}/web/icon-512.png" pinebook-control-512.png
}
