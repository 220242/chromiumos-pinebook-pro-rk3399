#!/bin/bash
# Make a ChromiumOS disk image for the Pinebook Pro bootable from microSD:
#  - write the boot loader (U-Boot + TF-A) at sector 64, where the RK3399 boot
#    ROM looks for it;
#  - copy boot.scr to the root of EFI-SYSTEM (partition 12), the partition
#    marked legacy-BIOS-bootable. The boot ROM tries SPI flash and eMMC before
#    the card, so on a laptop that already has a boot loader there (Manjaro's
#    U-Boot, Tow-Boot) that one runs instead of ours; its distro boot only
#    looks at the bootable partition. boot.scr loads the kernel from ROOT-A.
#    That partition also gets the Basic data type, so Windows can read the
#    boot logs written to it.
# Run it on the image file before writing the image to a microSD card.
#
# Usage: install-u-boot.sh IMAGE [LOADER [BOOT_SCR]]
#   IMAGE     chromiumos_image.bin (or test/base image) built for this board
#   LOADER    u-boot-rockchip.bin; default: the one sys-boot/pinebook-pro-u-boot
#             installed into the board sysroot under CHROMIUMOS_ROOT
#             (default ~/chromiumos)
#   BOOT_SCR  boot.scr; default: /boot/pinebook-pro/boot.scr in that sysroot
#
# The loader must fit inside partition 11 (RWFW), which the overlay's
# scripts/disk_layout.json makes 16 MiB. The script refuses to write if any
# other partition overlaps the loader. Needs sfdisk and mcopy (mtools).

set -euo pipefail

BOARD=pinebook-pro-rk3399
SECTOR=512
OFFSET_SECTORS=64

die() { echo "install-u-boot: $*" >&2; exit 1; }

[[ $# -ge 1 && $# -le 3 ]] || { sed -n '2,24s/^# \{0,1\}//p' "$0" >&2; exit 2; }

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
# By default the boot script comes from the same sysroot as the loader.
boot_scr=${3:-$(dirname "${loader}")/../../boot/pinebook-pro/boot.scr}

[[ -f ${image} ]] || die "no image: ${image}"
[[ -f ${loader} ]] || die "no loader: ${loader}"
command -v sfdisk >/dev/null || die "sfdisk (util-linux) is required"
command -v mcopy >/dev/null || die "mcopy is required (sudo apt install mtools)"
[[ -f ${boot_scr} ]] || die "no boot script: ${boot_scr}"

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
esp_start=$(sfdisk -d "${image}" | sed -n 's/^[^ ]*[^0-9]12 *: start= *\([0-9]*\),.*/\1/p')
[[ ${esp_start} =~ ^[0-9]+$ ]] || die "no partition 12 (EFI-SYSTEM) in ${image}"
echo "Copying ${boot_scr} to /boot.scr on partition 12 (EFI-SYSTEM)"
MTOOLS_SKIP_CHECK=1 mcopy -o -i "${image}@@$(( esp_start * SECTOR ))" "${boot_scr}" ::/boot.scr
# Basic data type instead of EFI System, so Windows mounts the partition and
# the boot logs that pinebook-boot-logs writes to logs/ can be read there.
# The legacy-BIOS-bootable attribute that distro boot looks for stays.
echo "Setting partition 12 (EFI-SYSTEM) type to Basic data"
sfdisk --quiet --part-type "${image}" 12 EBD0A0A2-B9E5-4433-87C0-68B6B72699C7
echo "Done. Write the image to the microSD card as usual."
