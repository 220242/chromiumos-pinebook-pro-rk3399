# Copyright 2022-2026 Gentoo Authors
# Copyright 2026 The chromiumos-pinebook-pro-rk3399 Authors
# Distributed under the terms of the GNU General Public License v2
# Adapted from ::gentoo app-containers/lxc for Waydroid on ChromiumOS: only
# what Waydroid uses (the lxc-* tools and liblxc), no systemd/OpenRC files, no
# AppArmor, seccomp or SELinux support (Waydroid's config is adjusted to match,
# see app-containers/waydroid), no setuid lxc-user-nic. EAPI 7: the SDK's
# Portage has no EAPI 8.

EAPI=7

inherit meson

DESCRIPTION="A userspace interface for the Linux kernel containment features"
HOMEPAGE="https://linuxcontainers.org/ https://github.com/lxc/lxc"
SRC_URI="https://github.com/lxc/lxc/archive/refs/tags/v${PV}.tar.gz -> ${P}.gh.tar.gz"

LICENSE="GPL-2 LGPL-2.1 LGPL-3"
SLOT="0/1.700"
KEYWORDS="*"
# mirror: not on the ChromeOS mirrors, fetch from SRC_URI despite force-mirror.
RESTRICT="mirror test"

RDEPEND="sys-libs/libcap"
DEPEND="${RDEPEND}
	sys-kernel/linux-headers"
BDEPEND="virtual/pkgconfig"

PATCHES=(
	"${FILESDIR}/${P}-glibc-2.43-const-fix.patch"
)

src_configure() {
	local emesonargs=(
		--localstatedir "${EPREFIX}/var"

		-Dapi-docs=false
		-Dapparmor=false
		-Dcapabilities=true
		-Dcommands=true
		-Dcoverity-build=false
		-Ddbus=false
		-Dexamples=false
		-Dinstall-init-files=false
		-Dinstall-state-dirs=false
		-Dio-uring-event-loop=false
		-Dlandlock-monitor=false
		-Dman=false
		-Dmemfd-rexec=true
		-Dopenssl=false
		-Doss-fuzz=false
		-Dpam-cgroup=false
		-Dseccomp=false
		-Dselinux=false
		-Dspecfile=false
		-Dtests=false
		-Dthread-safety=true
		-Dtools=true
		-Dtools-multicall=false

		-Ddata-path=/var/lib/lxc
		-Ddoc-path="/usr/share/doc/${PF}"
		-Dlog-path=/var/log/lxc
		# LXC mounts the container's root here while starting it. Not under
		# /var: ChromiumOS's /var is on the stateful partition, so a directory
		# the image installs there does not exist at run time.
		-Drootfs-mount-path=/usr/lib/lxc/rootfs
		-Druntime-path=/run
	)
	meson_src_configure
}

src_install() {
	meson_src_install

	# Unprivileged networking helper, installed setuid root; Waydroid runs a
	# privileged container and does not use it.
	rm "${ED}/usr/libexec/lxc/lxc-user-nic" || die
	find "${ED}" \( -name '*.la' -o -name '*.a' \) -delete || die

	keepdir /usr/lib/lxc/rootfs
}
