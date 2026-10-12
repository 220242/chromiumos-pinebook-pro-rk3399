#!/usr/bin/env bash
# Build a ChromiumOS disk image for the board in board.conf:
#   overlay  copy boards/<board>/overlay-<board> into the checkout
#   sdk      create or update the cros_sdk chroot
#   board    setup_board
#   packages cros build-packages
#   image    cros build-image, then export
#   export   copy the last built image to OUTPUT_DIR/images, with the board's
#            boot loader written into it, plus a .sha256
#   patch    fast path while porting: rebuild the packages in PATCH_PACKAGES,
#            install them into the last built image (with SELinux labels),
#            then export. Minutes instead of a full build_image.
#
# Usage: build/linux/build.sh [STAGE...]
#   With no stages, runs overlay sdk board packages image in order.
#   Example: build.sh packages image
#   Example: PATCH_PACKAGES=chromeos-base/chromeos-bsp-pinebook-pro-rk3399 \
#              build.sh overlay patch
# Settings: BOARD, CHROMIUMOS_ROOT, IMAGE_TYPE (base|dev|test), OUTPUT_DIR,
#           DRY_RUN (see common.sh).

# shellcheck source=build/linux/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

ALL_STAGES=(overlay sdk board packages image export patch)
DEFAULT_STAGES=(overlay sdk board packages image)
stages=("$@")
(( ${#stages[@]} )) || stages=("${DEFAULT_STAGES[@]}")
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
  stage_export
}

stage_export() {
  local src dst tmp
  src="$(image_path)"
  dst="${OUTPUT_DIR}/images/chromiumos-${BOARD}-${IMAGE_TYPE}.bin"
  if [[ "${DRY_RUN}" != "1" ]]; then
    [[ -f "${src}" ]] || die "No image at ${src}; run the image stage first"
  fi
  # Finish the image on the Linux file system, where the sparse copy, the
  # loader and the checksum are fast, then copy it out once.
  tmp="${CHROMIUMOS_ROOT}/.pinebook/export.bin"
  run mkdir -p "${tmp%/*}" "${OUTPUT_DIR}/images"
  run cp --sparse=always "${src}" "${tmp}"
  # The board's boot loader goes in front of the partitions (sector 64 on the
  # RK3399), so the copy in OUTPUT_DIR can be written to a card as is.
  local board_dir="${BOARD_CONF%/*}"
  local install_loader="${board_dir}/install-u-boot.sh"
  if [[ "${board_dir##*/}" == "${BOARD}" && -f "${install_loader}" ]]; then
    run env CHROMIUMOS_ROOT="${CHROMIUMOS_ROOT}" bash "${install_loader}" "${tmp}"
  fi
  if [[ "${DRY_RUN}" != "1" ]]; then
    echo "$(sha256sum "${tmp}" | cut -d' ' -f1)  $(basename "${dst}")" > "${dst}.sha256"
  fi
  run cp "${tmp}" "${dst}"
  run rm -f "${tmp}"
  ok "Image: ${dst}"
  info "Next: build/linux/flash-microsd.sh /dev/sdX ${dst}"
}

stage_patch() {
  [[ -n "${PATCH_PACKAGES:-}" ]] || die "Set PATCH_PACKAGES to the packages to rebuild and install"
  local src
  src="$(image_path)"
  if [[ "${DRY_RUN}" != "1" ]]; then
    [[ -f "${src}" ]] || die "No image at ${src}; run the image stage once first"
  fi
  # shellcheck disable=SC2086  # PATCH_PACKAGES is a list of atoms
  # --usepkg: reuse binary packages a packages stage already built.
  run cros_sdk -- "emerge-${BOARD}" --usepkg --jobs="${JOBS}" ${PATCH_PACKAGES}
  # The chroot only sees files inside the checkout.
  run mkdir -p "${CHROMIUMOS_ROOT}/.pinebook"
  run cp "${REPO_ROOT}/build/linux/patch-image-inner.sh" "${CHROMIUMOS_ROOT}/.pinebook/"
  # shellcheck disable=SC2086
  run cros_sdk -- bash /mnt/host/source/.pinebook/patch-image-inner.sh \
    "${BOARD}" "/mnt/host/source/${src#"${CHROMIUMOS_ROOT}"/}" ${PATCH_PACKAGES}
  stage_export
}

for s in "${stages[@]}"; do
  info "=== ${s} ==="
  "stage_${s}"
done
ok "Build finished: ${stages[*]}"
