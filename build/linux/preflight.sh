#!/usr/bin/env bash
# Check that this Linux or WSL2 machine can sync and build ChromiumOS.
# Changes nothing. Exits non-zero when a hard requirement is missing.
#
# Usage: build/linux/preflight.sh

# shellcheck source=build/linux/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

MIN_DISK_GB="${MIN_DISK_GB:-200}"
MIN_RAM_GB="${MIN_RAM_GB:-16}"
failed=0
fail() { printf '%s[FAIL]%s %s\n' "${_c_err}" "${_c_off}" "$*" >&2; failed=1; }

info "Board: ${BOARD}"
info "ChromiumOS checkout: ${CHROMIUMOS_ROOT}"

[[ "$(uname -s)" == "Linux" ]] || fail "ChromiumOS builds only on Linux (or WSL2 on Windows)."
[[ "$(uname -m)" == "x86_64" ]] || fail "The ChromiumOS SDK needs an x86_64 host (this is $(uname -m))."

if is_wsl; then
  if uname -r | grep -qi 'microsoft-standard'; then
    ok "Running in WSL2"
  else
    fail "This is WSL1. Convert the distro: wsl --set-version <distro> 2"
  fi
fi

[[ "${EUID}" -ne 0 ]] || fail "Run as a normal user with sudo rights, not as root."
if command -v sudo >/dev/null; then
  ok "sudo is installed (cros_sdk asks for it)"
else
  fail "sudo is missing."
fi

for tool in git curl python3 rsync xz; do
  if command -v "${tool}" >/dev/null; then ok "${tool} found"; else fail "${tool} is missing (sudo apt install ${tool/xz/xz-utils})"; fi
done

if [[ -n "$(git config --global user.email || true)" && -n "$(git config --global user.name || true)" ]]; then
  ok "git user.name and user.email are set"
else
  fail "Set git identity first: git config --global user.name ...; git config --global user.email ..."
fi

# The checkout must live on a native Linux filesystem.
check_dir="${CHROMIUMOS_ROOT}"
while [[ ! -d "${check_dir}" ]]; do check_dir="$(dirname "${check_dir}")"; done
if is_windows_mount "${check_dir}"; then
  fail "${CHROMIUMOS_ROOT} is on a Windows drive. Keep the checkout inside WSL (e.g. ~/chromiumos)."
else
  ok "Checkout location is on a Linux filesystem ($(stat -f -c %T "${check_dir}"))"
fi

free_gb=$(( $(df -Pk "${check_dir}" | awk 'NR==2 {print $4}') / 1024 / 1024 ))
if (( free_gb >= MIN_DISK_GB )); then
  ok "${free_gb} GB free at ${check_dir}"
else
  fail "Only ${free_gb} GB free at ${check_dir}; a checkout plus one board build needs about ${MIN_DISK_GB} GB."
fi

# Rounded: a 16 GB machine reports a little less than 16 GiB in MemTotal.
ram_gb=$(( ($(awk '/MemTotal/ {print $2}' /proc/meminfo) + 524288) / 1048576 ))
if (( ram_gb >= MIN_RAM_GB )); then
  ok "${ram_gb} GB RAM"
else
  warn "${ram_gb} GB RAM; ${MIN_RAM_GB} GB or more is recommended (on WSL2 raise 'memory=' in %UserProfile%\\.wslconfig)."
fi
ok "${JOBS} parallel jobs"

if [[ "$(umask)" == "0022" || "$(umask)" == "022" ]]; then
  ok "umask is 022"
else
  warn "umask is $(umask); the ChromiumOS docs require 022 (add 'umask 022' to ~/.bashrc)."
fi

if curl -fsS --max-time 15 -o /dev/null https://chromium.googlesource.com/chromiumos/manifest/+/HEAD; then
  ok "chromium.googlesource.com is reachable"
else
  fail "Cannot reach chromium.googlesource.com."
fi

if [[ -d "${OVERLAY_SRC}" || -d "${OVERLAY_DST}" ]]; then
  ok "Board overlay found"
else
  warn "No board overlay yet (${OVERLAY_SRC}); sync works, but setup_board will fail until it exists."
fi

if (( failed )); then
  die "Preflight found problems; fix the [FAIL] lines above."
fi
ok "Preflight passed"
