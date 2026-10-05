#!/bin/bash
# Write the Pinebook Pro boot loader (U-Boot + TF-A) into a ChromiumOS disk
# image, at sector 64 where the RK3399 boot ROM looks for it. Run it on the
# image file before writing the image to a microSD card.
#
# Usage: install-u-boot.sh IMAGE [LOADER]
#   IMAGE   chromiumos_image.bin (or test/base image) built for this board
#   LOADER  u-boot-rockchip.bin; default: the one sys-boot/pinebook-pro-u-boot
#           installed into the board sysroot under CHROMIUMOS_ROOT
#           (default ~/chromiumos)
#
# The loader must fit inside partition 11 (RWFW), which the overlay's
# scripts/disk_layout.json makes 16 MiB. The script refuses to write if any
# other partition overlaps the loader.

set -euo pipefail

BOARD=pinebook-pro-rk3399
SECTOR=512
OFFSET_SECTORS=64

die() { echo "install-u-boot: $*" >&2; exit 1; }

[[ $# -ge 1 && $# -le 2 ]] || { sed -n '2,14s/^# \{0,1\}//p' "$0" >&2; exit 2; }

image=$1
loader=${2:-}
if [[ -z ${loader} ]]; then
	root=${CHROMIUMOS_ROOT:-${HOME}/chromiumos}
	for sysroot in "${root}/out/build/${BOARD}" "${root}/chroot/build/${BOARD}" "/build/${BOARD}"; do
		if [[ -f ${sysroot}/firmware/pinebook-pro/u-boot-rockchip.bin ]]; then
			loader=${sysroot}/firmware/pinebook-pro/u-boot-rockchip.bin
			break
		fi
	done
	[[ -n ${loader} ]] || die "u-boot-rockchip.bin not found; build sys-boot/pinebook-pro-u-boot or pass LOADER"
fi

[[ -f ${image} ]] || die "no image: ${image}"
[[ -f ${loader} ]] || die "no loader: ${loader}"
command -v sfdisk >/dev/null || die "sfdisk (util-linux) is required"

loader_bytes=$(stat -c %s "${loader}")
first=${OFFSET_SECTORS}
last=$(( OFFSET_SECTORS + (loader_bytes + SECTOR - 1) / SECTOR - 1 ))

# Every partition except RWFW (11) must stay clear of sectors first..last,
# and RWFW must contain them.
rwfw_ok=0
while read -r dev start size; do
	num=${dev##*[!0-9]}
	end=$(( start + size - 1 ))
	if [[ ${num} == 11 ]]; then
		(( start <= first && end >= last )) && rwfw_ok=1
		continue
	fi
	if (( start <= last && end >= first )); then
		die "partition ${num} (sectors ${start}-${end}) overlaps the loader (sectors ${first}-${last}); was the image built with this overlay's disk_layout.json?"
	fi
done < <(sfdisk -d "${image}" | sed -n 's/^\([^ ]*\) *: start= *\([0-9]*\), size= *\([0-9]*\),.*/\1 \2 \3/p')

(( rwfw_ok )) || die "partition 11 (RWFW) does not cover sectors ${first}-${last}"

echo "Writing ${loader} (${loader_bytes} bytes) to ${image} at sector ${first}"
dd if="${loader}" of="${image}" bs=${SECTOR} seek=${OFFSET_SECTORS} conv=notrunc,fsync status=none
echo "Done. Write the image to the microSD card as usual."
