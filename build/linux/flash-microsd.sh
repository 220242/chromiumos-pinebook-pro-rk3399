#!/usr/bin/env bash
# Write a built image to a microSD card. ERASES THE WHOLE CARD.
#
# Usage: build/linux/flash-microsd.sh DEVICE [IMAGE] [--yes]
#   DEVICE  whole-disk block device of the card, e.g. /dev/sdb or /dev/mmcblk0
#   IMAGE   default: OUTPUT_DIR/images/chromiumos-<board>-<IMAGE_TYPE>.bin
#   --yes   skip the confirmation prompt
#
# In WSL2 the card reader is invisible unless attached with usbipd-win; it is
# usually simpler to write the image from Windows (see docs/WINDOWS_BUILD.md).

# shellcheck source=build/linux/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

assume_yes=0
args=()
for a in "$@"; do
  case "${a}" in
    --yes|-y) assume_yes=1 ;;
    -h|--help) sed -n '2,11s/^# \{0,1\}//p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) args+=("${a}") ;;
  esac
done
(( ${#args[@]} >= 1 && ${#args[@]} <= 2 )) || die "Usage: $0 DEVICE [IMAGE] [--yes]"

dev="${args[0]}"
img="${args[1]:-${OUTPUT_DIR}/images/chromiumos-${BOARD}-${IMAGE_TYPE}.bin}"

[[ -f "${img}" ]] || die "Image not found: ${img} (run build/linux/build.sh first)"
if [[ ! -b "${dev}" ]]; then
  is_wsl && die "${dev} is not a block device. WSL2 can't see card readers without usbipd-win; flash from Windows instead."
  die "${dev} is not a block device."
fi
[[ "$(lsblk -dno TYPE "${dev}")" == "disk" ]] \
  || die "${dev} is a partition; pass the whole disk (e.g. /dev/sdb, not /dev/sdb1)."

# Refuse the disk that holds / or /boot.
for mnt in / /boot /boot/efi; do
  src="$(findmnt -no SOURCE "${mnt}" 2>/dev/null || true)"
  [[ -n "${src}" && -b "${src}" ]] || continue
  parent="/dev/$(lsblk -no PKNAME "${src}" 2>/dev/null | head -n1)"
  [[ "${parent}" != "${dev}" && "${src}" != "${dev}" ]] \
    || die "${dev} holds ${mnt}; refusing to overwrite the system disk."
done

removable="$(lsblk -dno RM "${dev}" | tr -d ' ')"
tran="$(lsblk -dno TRAN "${dev}" | tr -d ' ')"
if [[ "${removable}" != "1" && "${tran}" != "usb" && "${dev}" != /dev/mmcblk* ]]; then
  warn "${dev} does not look removable (RM=${removable}, TRAN=${tran:-none})."
fi

lsblk -o NAME,SIZE,MODEL,TRAN,RM,MOUNTPOINTS "${dev}"
info "Image: ${img} ($(du -h --apparent-size "${img}" | cut -f1))"

if (( ! assume_yes )); then
  read -r -p "Everything on ${dev} will be erased. Type the device name to continue: " answer
  [[ "${answer}" == "${dev}" ]] || die "Cancelled."
fi

# Unmount any mounted partitions of the card.
while read -r part mp; do
  [[ -n "${mp}" ]] && run sudo umount "/dev/${part}"
done < <(lsblk -lno NAME,MOUNTPOINT "${dev}" | tail -n +2)

run sudo dd if="${img}" of="${dev}" bs=4M conv=fsync oflag=direct status=progress
run sync
ok "Wrote ${img} to ${dev}"
warn "The Pinebook Pro also needs U-Boot (in SPI flash or on the card) to boot this image; see docs/WINDOWS_BUILD.md."
