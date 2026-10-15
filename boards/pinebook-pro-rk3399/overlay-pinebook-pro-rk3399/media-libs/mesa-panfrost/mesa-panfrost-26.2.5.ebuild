# Copyright 2026 The chromiumos-pinebook-pro-rk3399 Authors
# Distributed under the terms of the GNU General Public License v2

# Mesa 26 with the Panfrost driver for the Pinebook Pro's Mali-T860 (Midgard),
# from the upstream release instead of ChromiumOS's mesa-23.3.0 branch. The
# configuration follows chromiumos-overlay's mesa-panfrost-23.3.0: EGL and
# GLES 2/3 only, no GBM (minigbm provides it), surfaceless platform.
#
# Since Mesa 25 Panfrost's build compiles OpenCL C helpers ("libpan") with
# mesa_clc, vtn_bindgen2 and panfrost_compile, which have to run on the build
# machine. src_configure first builds them natively against ChromeOS's
# dev-util/spirv-llvm (LLVM 16, clang and the SPIR-V translator in
# /opt/spirv-llvm, the same setup as dev-util/intel_clc), then configures the
# target with -Dmesa-clc=system -Dprecomp-compiler=system.

EAPI=7

PYTHON_COMPAT=( python3_{8..13} )

inherit meson flag-o-matic python-any-r1 toolchain-funcs

DESCRIPTION="The Mesa 3D Graphics Library (Panfrost)"
HOMEPAGE="https://mesa3d.org/"
SRC_URI="https://archive.mesa3d.org/mesa-${PV}.tar.xz"
S="${WORKDIR}/mesa-${PV}"

# Most of the code is MIT/X11.
# GLES[2]/gl[2]{,ext,platform}.h are SGI-B-2.0
LICENSE="MIT SGI-B-2.0"
SLOT="0"
KEYWORDS="*"
IUSE="debug libglvnd vulkan zstd"
RESTRICT="mirror"

COMMON_DEPEND="
	dev-libs/expat:=
	>=x11-libs/libdrm-2.4.121:=
	sys-libs/zlib
"

RDEPEND="${COMMON_DEPEND}
	libglvnd? ( media-libs/libglvnd )
	!libglvnd? ( !media-libs/libglvnd )
	zstd? ( app-arch/zstd )
"

DEPEND="${COMMON_DEPEND}"

# Build machine: the precompiled-shader tools (see above).
BDEPEND="
	dev-libs/libclc
	dev-util/spirv-llvm
	dev-util/spirv-tools
	sys-devel/bison
	sys-devel/flex
	virtual/pkgconfig
	x11-libs/libdrm
	$(python_gen_any_dep '
		dev-python/mako[${PYTHON_USEDEP}]
		dev-python/pyyaml[${PYTHON_USEDEP}]
	')
"

python_check_deps() {
	python_has_version -b "dev-python/mako[${PYTHON_USEDEP}]" &&
		python_has_version -b "dev-python/pyyaml[${PYTHON_USEDEP}]"
}

HOST_BUILD="${WORKDIR}/host-tools"

build_host_tools() {
	local spirv_llvm="/opt/spirv-llvm"
	einfo "Building mesa_clc, vtn_bindgen2 and panfrost_compile for the build machine"
	(
		# A plain native build, without any of the cross-compile setup.
		unset AR AS CC CPP CXX LD NM OBJCOPY RANLIB READELF STRIP
		unset CFLAGS CPPFLAGS CXXFLAGS LDFLAGS
		unset PKG_CONFIG PKG_CONFIG_LIBDIR PKG_CONFIG_PATH PKG_CONFIG_SYSROOT_DIR
		unset SYSROOT
		export CC="$(tc-getBUILD_CC)" CXX="$(tc-getBUILD_CXX)"
		export AR="$(tc-getBUILD_AR)" PKG_CONFIG="$(tc-getBUILD_PKG_CONFIG)"
		export PKG_CONFIG_PATH="${spirv_llvm}/lib/pkgconfig:/usr/lib64/pkgconfig:/usr/share/pkgconfig"
		export CPPFLAGS="-I${spirv_llvm}/include"
		export LDFLAGS="-L${spirv_llvm}/lib"
		cat > "${T}/host.ini" <<-EOF || die
			[binaries]
			llvm-config = '${spirv_llvm}/bin/llvm-config'
		EOF
		meson setup "${HOST_BUILD}" "${S}" --native-file "${T}/host.ini" \
			--buildtype=release --wrap-mode=nodownload \
			-Dcmake_prefix_path="${spirv_llvm}/lib/cmake" \
			-Dllvm=enabled -Dshared-llvm=disabled -Dstatic-libclc=all \
			-Dmesa-clc=enabled -Dinstall-mesa-clc=true \
			-Dprecomp-compiler=enabled -Dinstall-precomp-compiler=true \
			-Dgallium-drivers=panfrost -Dvulkan-drivers= -Dplatforms= \
			-Dglx=disabled -Degl=disabled -Dgbm=disabled -Dopengl=false \
			-Dgles1=disabled -Dgles2=disabled -Dglvnd=disabled \
			-Dzstd=disabled -Dvalgrind=disabled -Dlibunwind=disabled \
			-Dlmsensors=disabled -Dxmlconfig=disabled -Dexpat=disabled \
			-Dvideo-codecs= \
			|| die "meson setup for the build machine failed"
		meson compile -C "${HOST_BUILD}" mesa_clc vtn_bindgen2 panfrost_compile \
			|| die "building the precompiled-shader tools failed"
	) || die
}

src_configure() {
	python_setup
	build_host_tools

	local tools
	tools=$(dirname "$(find "${HOST_BUILD}" -type f -name mesa_clc -perm -u+x | head -n1)")
	tools+=":$(dirname "$(find "${HOST_BUILD}" -type f -name vtn_bindgen2 -perm -u+x | head -n1)")"
	tools+=":$(dirname "$(find "${HOST_BUILD}" -type f -name panfrost_compile -perm -u+x | head -n1)")"
	export PATH="${tools}:${PATH}"

	emesonargs+=(
		-Dglvnd=$(usex libglvnd enabled disabled)
		-Dllvm=disabled
		-Dmesa-clc=system
		-Dprecomp-compiler=system
		-Dshader-cache=disabled
		-Dglx=disabled
		-Degl=enabled
		-Dgbm=disabled
		-Dgles1=disabled
		-Dgles2=enabled
		-Dshared-glapi=enabled
		-Dgallium-drivers=panfrost
		-Dgallium-va=disabled
		-Dvideo-codecs=
		$(meson_feature zstd)
		-Dplatforms=
		--buildtype $(usex debug debug release)
		-Dvulkan-drivers=$(usex vulkan panfrost '')
	)

	meson_src_configure
}

src_install() {
	meson_src_install

	rm -v -rf "${ED}/usr/include"
}
