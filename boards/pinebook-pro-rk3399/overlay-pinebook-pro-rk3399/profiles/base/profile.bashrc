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
_pinebook_pro_kernel_build_dir() {
	local cfg
	cfg=$(find "${WORKDIR}" -maxdepth 4 -name .config -path '*build*' \
		-not -path "${S}/*" -print -quit)
	[[ -n ${cfg} ]] || die "pinebook-pro: kernel .config not found in ${WORKDIR}"
	dirname "${cfg}"
}

cros_post_src_configure_pinebook_pro_kernel_config() {
	_pinebook_pro_is_kernel || return 0
	local build_dir make_args=( ARCH=arm64 )
	build_dir=$(_pinebook_pro_kernel_build_dir)
	[[ $(tc-getCC) == *clang* ]] && make_args+=( LLVM=1 )
	einfo "pinebook-pro: merging kernel/pinebook-pro.config into ${build_dir}/.config"
	"${PINEBOOK_PRO_OVERLAY}/kernel/apply-fragment.sh" "${S}" "${build_dir}" \
		"${PINEBOOK_PRO_OVERLAY}/kernel/pinebook-pro.config" \
		"${make_args[@]}" CROSS_COMPILE="${CHOST}-" \
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
