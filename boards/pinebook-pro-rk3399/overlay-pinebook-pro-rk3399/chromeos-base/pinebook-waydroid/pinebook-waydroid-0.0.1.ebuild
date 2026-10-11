# Copyright 2026 The chromiumos-pinebook-pro-rk3399 Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# A wide range, with unknown ones ignored: the board's Python and the
# eclass's list of implementations depend on the ChromiumOS checkout.
PYTHON_COMPAT=( python3_{9..15} )
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
RDEPEND="${PYTHON_DEPS}
	app-containers/waydroid
	sys-apps/dbus
	sys-fs/e2fsprogs
	$(python_gen_cond_dep 'dev-python/dbus-python[${PYTHON_USEDEP}]')
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
}
