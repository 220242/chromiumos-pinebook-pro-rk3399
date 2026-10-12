# Copyright 2026 The chromiumos-pinebook-pro-rk3399 Authors
# Distributed under the terms of the GNU General Public License v2

# EAPI 7: the SDK's Portage has no EAPI 8.
EAPI=7

# A wide range, with unknown ones ignored: the board's Python and the
# eclass's list of implementations depend on the ChromiumOS checkout.
PYTHON_COMPAT=( python3_{8..15} )
PYTHON_COMPAT_NO_STRICT=1

inherit python-single-r1

DESCRIPTION="Android apps (Waydroid) in one step: http://android.localhost and the android command"
HOMEPAGE="https://github.com/220242/chromiumos-pinebook-pro-rk3399"
S="${WORKDIR}"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="*"
REQUIRED_USE="${PYTHON_REQUIRED_USE}"

# e2fsprogs: mkfs.ext4 and e2fsck for the ANDROID-DATA partition.
# dbus-python without a USE dependency, as in app-containers/waydroid.
RDEPEND="${PYTHON_DEPS}
	app-containers/waydroid
	dev-python/dbus-python
	sys-apps/dbus
	sys-fs/e2fsprogs
"

src_install() {
	# The service (root), started by the upstart job when someone logs in.
	python_scriptinto /usr/sbin
	python_doscript "${FILESDIR}/pinebook-android"
	insinto /etc/init
	doins "${FILESDIR}/pinebook-android.conf"

	# The command for a shell (crosh's `shell`, or VT2).
	python_scriptinto /usr/bin
	python_doscript "${FILESDIR}/android"

	insinto /usr/share/pinebook-android
	doins "${FILESDIR}/session-bus.conf"
	doins -r "${FILESDIR}/web"

	# The page as an app in the launcher from the first login, for every
	# user and for guests: Chrome installs the web apps described in
	# <extensions dir>/web_apps/*.json when a profile loads. The offline
	# manifest makes it install without loading the page. Branded Chrome
	# reads /usr/share/google-chrome, Chromium /usr/share/chromium.
	local dir
	for dir in google-chrome chromium; do
		insinto "/usr/share/${dir}/extensions/web_apps"
		doins "${FILESDIR}/launcher/pinebook-android.json"
		newins "${FILESDIR}/web/icon-192.png" pinebook-android-192.png
		newins "${FILESDIR}/web/icon-512.png" pinebook-android-512.png
	done
}
