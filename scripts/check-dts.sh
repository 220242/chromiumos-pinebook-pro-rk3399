#!/usr/bin/env bash
# Compile every device tree overlay in boards/*/overlays and apply it to the
# upstream Linux rk3399-pinebook-pro.dtb to prove the &label references resolve.
#
# Usage: scripts/check-dts.sh [path-to-linux-source]
# Without an argument, a sparse shallow clone of torvalds/linux is made in a
# temporary directory. Needs: git, cpp, dtc, fdtoverlay (device-tree-compiler).
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

linux="${1:-}"
if [[ -z "$linux" ]]; then
	linux="$work/linux"
	git clone -q --depth 1 --filter=blob:none --sparse https://github.com/torvalds/linux.git "$linux"
	git -C "$linux" sparse-checkout set arch/arm64/boot/dts/rockchip include/dt-bindings include/uapi/linux scripts/dtc
fi

dts_dir="$linux/arch/arm64/boot/dts/rockchip"
cpp -nostdinc -undef -D__DTS__ -x assembler-with-cpp \
	-I "$linux/scripts/dtc/include-prefixes" -I "$dts_dir" \
	"$dts_dir/rk3399-pinebook-pro.dts" > "$work/base.dts"
dtc -@ -q -I dts -O dtb -o "$work/base.dtb" "$work/base.dts"

status=0
for dts in "$repo_root"/boards/*/overlays/*.dts; do
	name="$(basename "$dts" .dts)"
	# Treat any dtc warning as a failure.
	if dtc -@ -I dts -O dtb -o "$work/$name.dtbo" "$dts" 2> "$work/$name.log" &&
		[[ ! -s "$work/$name.log" ]] &&
		fdtoverlay -i "$work/base.dtb" -o "$work/$name.dtb" "$work/$name.dtbo"; then
		echo "OK   $dts"
	else
		echo "FAIL $dts"
		cat "$work/$name.log" >&2
		status=1
	fi
done
exit $status
