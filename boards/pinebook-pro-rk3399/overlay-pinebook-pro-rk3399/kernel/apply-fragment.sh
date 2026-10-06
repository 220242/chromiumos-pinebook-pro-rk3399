#!/bin/bash
# Merge a kernel config fragment into an existing .config, run olddefconfig,
# then fail if any symbol from the fragment did not survive (for example
# because a dependency is missing in the base config).
#
# Usage: apply-fragment.sh KERNEL_SRC BUILD_DIR FRAGMENT [MAKE_ARG...]
#   KERNEL_SRC  kernel source tree
#   BUILD_DIR   output directory holding the .config (O= for make)
#   FRAGMENT    config fragment, e.g. kernel/pinebook-pro.config
#   MAKE_ARG    extra make arguments, e.g. ARCH=arm64 LLVM=1
#
# Used by profiles/base/profile.bashrc inside the ChromiumOS SDK, and can be
# run by hand on a plain kernel tree:
#   make ARCH=arm64 O=out defconfig
#   apply-fragment.sh . out kernel/pinebook-pro.config ARCH=arm64

set -euo pipefail

if [[ $# -lt 3 ]]; then
	sed -n '2,15s/^# \{0,1\}//p' "$0" >&2
	exit 2
fi

src=$(realpath "$1")
out=$(realpath "$2")
fragment=$(realpath "$3")
shift 3

config="${out}/.config"
[[ -f "${config}" ]] || { echo "apply-fragment: no ${config}" >&2; exit 1; }
[[ -f "${fragment}" ]] || { echo "apply-fragment: no ${fragment}" >&2; exit 1; }

# merge_config.sh makes its temporary file in the current directory; the
# kernel source is read-only inside the SDK's sandbox, so run it in ${out}.
(cd "${out}" && "${src}/scripts/kconfig/merge_config.sh" -m -O "${out}" "${config}" "${fragment}") >/dev/null
make -s -C "${src}" O="${out}" "$@" olddefconfig

# Compare what the fragment asked for with what olddefconfig kept. A module
# that became built in is fine.
bad=0
while IFS= read -r line; do
	if [[ ${line} =~ ^(CONFIG_[A-Za-z0-9_]+)=(.*)$ ]]; then
		key=${BASH_REMATCH[1]}
		want=${BASH_REMATCH[2]}
	elif [[ ${line} =~ ^#\ (CONFIG_[A-Za-z0-9_]+)\ is\ not\ set$ ]]; then
		key=${BASH_REMATCH[1]}
		want=n
	else
		continue
	fi
	got=$(sed -n "s/^${key}=//p" "${config}")
	got=${got:-n}
	if [[ ${got} != "${want}" && ! ( ${want} == m && ${got} == y ) ]]; then
		echo "apply-fragment: ${key} wanted ${want}, got ${got}" >&2
		bad=1
	fi
done < "${fragment}"

exit "${bad}"
