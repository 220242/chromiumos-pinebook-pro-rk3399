#!/usr/bin/env bash
# Build a ChromiumOS disk image for the board in board.conf:
#   overlay  copy boards/<board>/overlay-<board> into the checkout
#   sdk      create or update the cros_sdk chroot
#   board    setup_board
#   packages cros build-packages
#   image    cros build-image, then copy the result to OUTPUT_DIR/images
#
# Usage: build/linux/build.sh [STAGE...]
#   With no stages, runs all of them in order. Example: build.sh packages image
# Settings: BOARD, CHROMIUMOS_ROOT, IMAGE_TYPE (base|dev|test), OUTPUT_DIR,
#           DRY_RUN (see common.sh).

# shellcheck source=build/linux/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

ALL_STAGES=(overlay sdk board packages image)
stages=("$@")
(( ${#stages[@]} )) || stages=("${ALL_STAGES[@]}")
for s in "${stages[@]}"; do
  [[ " ${ALL_STAGES[*]} " == *" ${s} "* ]] || die "Unknown stage '${s}'. Stages: ${ALL_STAGES[*]}"
done
image_path >/dev/null  # validates IMAGE_TYPE early

start_log build
need_depot_tools
need_checkout
cd "${CHROMIUMOS_ROOT}" 2>/dev/null || missing "Cannot enter ${CHROMIUMOS_ROOT}"

info "Board: ${BOARD}, image type: ${IMAGE_TYPE}, stages: ${stages[*]}"

stage_overlay() {
  if [[ -d "${OVERLAY_SRC}" ]]; then
    # A checkout made on Windows can turn LF into CRLF, which breaks
    # profile.bashrc and the ebuilds in every package build.
    local crlf
    crlf="$(grep -rlI $'\r' "${OVERLAY_SRC}" || true)"
    [[ -z "${crlf}" ]] || die "CRLF line endings in the overlay (re-checkout with LF):"$'\n'"${crlf}"
    # Copied, not symlinked: the chroot only sees files inside the checkout.
    info "Copying ${OVERLAY_SRC} -> ${OVERLAY_DST}"
    run mkdir -p "${OVERLAY_DST}"
    # Files portage creates there (e.g. a Manifest) are root-owned, so copy no
    # owner, group, permissions or times, and compare by content instead.
    run rsync -rlD --checksum --delete "${OVERLAY_SRC}/" "${OVERLAY_DST}/"
  elif [[ -d "${OVERLAY_DST}" ]]; then
    warn "No overlay in this repo; using the one already in ${OVERLAY_DST}"
  else
    missing "No board overlay for ${BOARD}. Create ${OVERLAY_SRC} (see docs/PORTING_GUIDE.md)."
  fi
}

stage_sdk() {
  info "Creating/updating the SDK chroot (first run downloads the SDK)"
  run cros_sdk --create
}

stage_board() {
  run cros_sdk -- setup_board --board="${BOARD}"
}

stage_packages() {
  run cros_sdk -- cros build-packages --board="${BOARD}"
}

stage_image() {
  # Rootfs verification is off so the image can be modified while porting.
  run cros_sdk -- cros build-image --board="${BOARD}" \
    --no-enable-rootfs-verification "${IMAGE_TYPE}"

  local src dst
  src="$(image_path)"
  dst="${OUTPUT_DIR}/images/chromiumos-${BOARD}-${IMAGE_TYPE}.bin"
  if [[ "${DRY_RUN}" != "1" ]]; then
    [[ -f "${src}" ]] || die "build_image finished but ${src} is missing"
  fi
  run mkdir -p "${OUTPUT_DIR}/images"
  run cp --sparse=always "${src}" "${dst}"
  # The board's boot loader goes in front of the partitions (sector 64 on the
  # RK3399), so the copy in OUTPUT_DIR can be written to a card as is.
  local board_dir="${BOARD_CONF%/*}"
  local install_loader="${board_dir}/install-u-boot.sh"
  if [[ "${board_dir##*/}" == "${BOARD}" && -f "${install_loader}" ]]; then
    run env CHROMIUMOS_ROOT="${CHROMIUMOS_ROOT}" bash "${install_loader}" "${dst}"
  fi
  if [[ "${DRY_RUN}" != "1" ]]; then
    (cd "${OUTPUT_DIR}/images" && sha256sum "$(basename "${dst}")" > "$(basename "${dst}").sha256")
  fi
  ok "Image: ${dst}"
  info "Next: build/linux/flash-microsd.sh /dev/sdX ${dst}"
}

for s in "${stages[@]}"; do
  info "=== ${s} ==="
  "stage_${s}"
done
ok "Build finished: ${stages[*]}"
