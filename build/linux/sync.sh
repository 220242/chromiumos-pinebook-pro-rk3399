#!/usr/bin/env bash
# Fetch depot_tools and the ChromiumOS source tree with repo.
# Safe to re-run: an existing checkout is just synced again.
#
# Usage: build/linux/sync.sh
# Settings: CHROMIUMOS_ROOT, DEPOT_TOOLS, MANIFEST_URL, MANIFEST_BRANCH, JOBS,
#           DRY_RUN (see common.sh).

# shellcheck source=build/linux/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
start_log sync

if is_windows_mount "${CHROMIUMOS_ROOT}"; then
  die "${CHROMIUMOS_ROOT} is on a Windows drive. Keep the checkout inside WSL (e.g. ~/chromiumos)."
fi

if [[ -d "${DEPOT_TOOLS}/.git" ]]; then
  info "Updating depot_tools in ${DEPOT_TOOLS}"
  run git -C "${DEPOT_TOOLS}" pull --ff-only --quiet
else
  info "Cloning depot_tools into ${DEPOT_TOOLS}"
  run git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git "${DEPOT_TOOLS}"
fi

run mkdir -p "${CHROMIUMOS_ROOT}"
if [[ "${DRY_RUN}" != "1" ]]; then cd "${CHROMIUMOS_ROOT}" || exit 1; fi

if [[ -d "${CHROMIUMOS_ROOT}/.repo" ]]; then
  info "Checkout exists, switching manifest to ${MANIFEST_BRANCH}"
fi
run repo init -u "${MANIFEST_URL}" -b "${MANIFEST_BRANCH}"

info "Syncing source (first sync downloads tens of GB)"
run repo sync -j"${JOBS}" --current-branch --no-tags

ok "Source is in ${CHROMIUMOS_ROOT}"
info "Add depot_tools to PATH in your shell: export PATH=\"${DEPOT_TOOLS}:\$PATH\""
info "Next: build/linux/build.sh"
