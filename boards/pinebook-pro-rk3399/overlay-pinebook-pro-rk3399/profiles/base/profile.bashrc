# Board hooks for the ChromeOS kernel (sys-kernel/chromeos-kernel-*):
#  - after src_configure, merge kernel/pinebook-pro.config into the build
#    config and fail if any symbol from it is dropped;
#  - after src_install, install the kernel Image and the Pinebook Pro device
#    tree under /boot/pinebook-pro/, where boot.scr (installed by
#    chromeos-base/chromeos-bsp-pinebook-pro-rk3399) loads them from.

PINEBOOK_PRO_OVERLAY="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

_pinebook_pro_is_kernel() {
	[[ ${CATEGORY} == "sys-kernel" && ${PN} == chromeos-kernel-* ]]
}

# The kernel is built out of tree; find the directory holding its .config.
# cros-kernel builds incrementally under ${SYSROOT}/var/cache/portage, not in
# ${WORKDIR}, so ask the eclass first.
_pinebook_pro_kernel_build_dir() {
	if declare -F cros-workon_get_build_dir >/dev/null; then
		cros-workon_get_build_dir
		return
	fi
	local cfg
	cfg=$(find "${WORKDIR}" -maxdepth 4 -name .config -path '*build*' \
		-not -path "${S}/*" -print -quit)
	[[ -n ${cfg} ]] || die "pinebook-pro: kernel .config not found in ${WORKDIR}"
	dirname "${cfg}"
}

cros_post_src_configure_pinebook_pro_kernel_config() {
	_pinebook_pro_is_kernel || return 0
	local build_dir
	build_dir=$(_pinebook_pro_kernel_build_dir)
	# The same prefixed tools cros-kernel's kmake uses: the SDK refuses plain
	# clang, ld.bfd and friends, and Kconfig probes the compiler and linker.
	local make_args=(
		ARCH=arm64
		CC="$(tc-getCC)" LD=ld.lld AR=llvm-ar NM=llvm-nm
		OBJCOPY=llvm-objcopy STRIP=llvm-strip
		CLANG_CROSS_FLAGS="--target=${CHOST}"
		HOSTCC="$(tc-getBUILD_CC)" HOSTCXX="$(tc-getBUILD_CXX)"
		HOSTLD="$(tc-getBUILD_LD)" HOSTPKG_CONFIG="$(tc-getBUILD_PKG_CONFIG)"
	)
	use llvm_ias && make_args+=( LLVM_IAS=1 )
	einfo "pinebook-pro: merging kernel/pinebook-pro.config into ${build_dir}/.config"
	"${PINEBOOK_PRO_OVERLAY}/kernel/apply-fragment.sh" "${S}" "${build_dir}" \
		"${PINEBOOK_PRO_OVERLAY}/kernel/pinebook-pro.config" "${make_args[@]}" \
		|| die "pinebook-pro: kernel config fragment did not apply"
}

cros_post_src_install_pinebook_pro_kernel_boot_files() {
	_pinebook_pro_is_kernel || return 0
	local build_dir dtb
	build_dir=$(_pinebook_pro_kernel_build_dir)
	dtb="${build_dir}/arch/arm64/boot/dts/rockchip/rk3399-pinebook-pro.dtb"
	[[ -f ${dtb} ]] || die "pinebook-pro: ${dtb} was not built (is USE=device_tree set?)"
	insinto /boot/pinebook-pro
	newins "${build_dir}/arch/arm64/boot/Image" Image
	doins "${dtb}"
}

# minigbm (media-libs/minigbm): add a backend for the Panfrost render node,
# minigbm/panfrost.c. Chrome creates its GBM device on the first render
# node, which on this board is Panfrost's (rockchipdrm has none); without a
# backend for it there was no hardware video decoding, and ozone and the
# camera service fell back to dumb buffers.
_pinebook_pro_is_minigbm() {
	[[ ${CATEGORY} == "media-libs" && ${PN} == "minigbm" ]]
}

cros_pre_src_prepare_pinebook_pro_minigbm_panfrost() {
	_pinebook_pro_is_minigbm || return 0
	# minigbm is built out of tree from the read-only source checkout: build a
	# private copy (without .git) that has panfrost.c and the patched drv.c.
	local src="${WORKDIR}/minigbm-pinebook-pro"
	if [[ ${S} != "${src}" ]]; then
		einfo "pinebook-pro: building minigbm from a copy with the panfrost backend"
		rm -rf "${src}"
		mkdir -p "${src}" || die
		tar -C "${S}" --exclude=.git -cf - . | tar -C "${src}" -xf - \
			|| die "pinebook-pro: copying the minigbm sources"
		S="${src}"
		cd "${S}" || die
	fi
	cp "${PINEBOOK_PRO_OVERLAY}/minigbm/panfrost.c" "${S}/panfrost.c" \
		|| die "pinebook-pro: copying panfrost.c"
	grep -q 'backend_panfrost' "${S}/drv.c" && return 0
	sed -i \
		-e '/^extern const struct backend backend_vkms;$/a #ifdef DRV_PANFROST\nextern const struct backend backend_panfrost;\n#endif' \
		-e 's/^\t&backend_evdi,/#ifdef DRV_PANFROST\n\t\&backend_panfrost,\n#endif\n&/' \
		"${S}/drv.c" || die "pinebook-pro: patching drv.c"
	grep -q '&backend_panfrost,' "${S}/drv.c" \
		|| die "pinebook-pro: drv.c did not take the panfrost backend"
}

cros_pre_src_configure_pinebook_pro_minigbm_panfrost() {
	_pinebook_pro_is_minigbm || return 0
	append-cppflags -DDRV_PANFROST
}
