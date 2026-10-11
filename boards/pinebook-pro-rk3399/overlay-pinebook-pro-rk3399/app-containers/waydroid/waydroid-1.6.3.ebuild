# Copyright 2022-2026 Gentoo Authors
# Copyright 2026 The chromiumos-pinebook-pro-rk3399 Authors
# Distributed under the terms of the GNU General Public License v2
# Adapted from ::guru app-containers/waydroid for ChromiumOS: no systemd,
# OpenRC, polkit, AppArmor, nftables or PulseAudio, and no PyGObject (files/gi
# has the parts of GLib Waydroid uses). The container is started by
# chromeos-base/pinebook-waydroid, which also provides the Wayland display
# (Chrome's) and the session bus.

EAPI=8

# A wide range, with unknown ones ignored: the board's Python and the
# eclass's list of implementations depend on the ChromiumOS checkout.
PYTHON_COMPAT=( python3_{9..15} )
PYTHON_COMPAT_NO_STRICT=1

inherit python-single-r1

DESCRIPTION="Container-based approach to boot a full Android system on Linux systems"
HOMEPAGE="https://waydro.id https://github.com/waydroid/waydroid"
SRC_URI="https://github.com/${PN}/${PN}/archive/${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="*"
# mirror: not on the ChromeOS mirrors, fetch from SRC_URI despite force-mirror.
RESTRICT="mirror"
REQUIRED_USE="${PYTHON_REQUIRED_USE}"

# PyGObject is replaced by files/gi: it needs GObject introspection, which
# ChromiumOS does not cross-compile for its boards. The stand-in calls
# libglib (dev-libs/glib) through ctypes.
RDEPEND="${PYTHON_DEPS}
	app-containers/lxc
	dev-libs/glib:2
	net-dns/dnsmasq
	net-firewall/iptables
	sys-apps/dbus
	sys-apps/iproute2
	sys-apps/kmod
	$(python_gen_cond_dep '
		dev-python/dbus-python[${PYTHON_USEDEP}]
		>=dev-python/gbinder-1.3.0[${PYTHON_USEDEP}]
	')
"

src_prepare() {
	default

	# app-containers/lxc here is built without AppArmor and seccomp, and LXC
	# rejects a config that uses either (https://github.com/waydroid/waydroid/issues/652).
	sed -i -e '/^lxc\.apparmor\.profile =/d' -e '/^lxc\.seccomp\./d' \
		data/configs/config_3 data/configs/config_4 || die
	# Without the seccomp profile, which turned clock changes into no-ops,
	# Android must not get CAP_SYS_TIME: it would set ChromeOS's clock.
	sed -i -e '/^lxc\.cap\.keep =/ s/ sys_time / /' data/configs/config_base || die
	# The checksum rule only fixes DHCP for very old clients; do not let a
	# kernel without the CHECKSUM target stop the container from starting.
	sed -i -e '/-j CHECKSUM --checksum-fill$/ s/$/ || true/' \
		data/scripts/waydroid-net.sh || die

	if grep -q -e '^lxc\.apparmor\.' -e '^lxc\.seccomp\.' data/configs/config_* ||
		grep -q '^lxc\.cap\.keep =.* sys_time ' data/configs/config_base ||
		[[ $(grep -c 'CHECKSUM --checksum-fill || true$' data/scripts/waydroid-net.sh) != 2 ]]; then
		die "ChromeOS adjustments to the LXC/network config did not apply"
	fi
}

src_install() {
	python_fix_shebang waydroid.py

	local mymakeargs=(
		DESTDIR="${D}"
		PREFIX="${EPREFIX}/usr"
		USE_DBUS_ACTIVATION=0
		USE_NFTABLES=0
		USE_SYSTEMD=0
	)
	emake "${mymakeargs[@]}" install

	# ChromeOS's dbus-daemon reads its policy from /etc/dbus-1/system.d.
	insinto /etc/dbus-1/system.d
	doins dbus/id.waydro.Container.conf
	rm -r "${ED}/usr/share/dbus-1" "${ED}/usr/share/polkit-1" || die

	# Next to waydroid.py, so `import gi` finds it first.
	insinto /usr/lib/waydroid
	doins -r "${FILESDIR}/gi"
	# The release tarball's directories are group-writable.
	chmod -R go-w "${ED}/usr/lib/waydroid" || die

	python_optimize "${ED}/usr/lib/waydroid"
}
