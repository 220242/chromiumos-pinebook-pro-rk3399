# shellcheck shell=bash
# Shared helpers for the build/linux/*.sh scripts. Source it, don't run it.
#
# Settings (environment variables, all optional):
#   BOARD            board name; default: BOARD_NAME from boards/*/board.conf
#   CHROMIUMOS_ROOT  ChromiumOS checkout; default: ~/chromiumos
#   DEPOT_TOOLS      depot_tools checkout; default: ~/depot_tools
#   MANIFEST_URL     default: https://chromium.googlesource.com/chromiumos/manifest
#   MANIFEST_BRANCH  default: main (or e.g. release-R130-16033.B)
#   IMAGE_TYPE       base | dev | test; default: test
#   OUTPUT_DIR       where finished images and logs go; default: <repo>/output
#   JOBS             parallel jobs; default: nproc
#   DRY_RUN=1        print commands instead of running them

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BOARD_CONF="${BOARD_CONF:-${REPO_ROOT}/boards/pinebook-pro-rk3399/board.conf}"

if [[ -z "${BOARD:-}" ]]; then
  [[ -f "${BOARD_CONF}" ]] || { echo "board.conf not found: ${BOARD_CONF}" >&2; exit 1; }
  BOARD="$(sed -n 's/^BOARD_NAME="\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' "${BOARD_CONF}")"
  [[ -n "${BOARD}" ]] || { echo "BOARD_NAME is not set in ${BOARD_CONF}" >&2; exit 1; }
fi

CHROMIUMOS_ROOT="${CHROMIUMOS_ROOT:-${HOME}/chromiumos}"
DEPOT_TOOLS="${DEPOT_TOOLS:-${HOME}/depot_tools}"
MANIFEST_URL="${MANIFEST_URL:-https://chromium.googlesource.com/chromiumos/manifest}"
MANIFEST_BRANCH="${MANIFEST_BRANCH:-main}"
IMAGE_TYPE="${IMAGE_TYPE:-test}"
OUTPUT_DIR="${OUTPUT_DIR:-${REPO_ROOT}/output}"
JOBS="${JOBS:-$(nproc)}"
DRY_RUN="${DRY_RUN:-0}"

# Board overlay kept in this repo and copied into the checkout before a build.
OVERLAY_SRC="${OVERLAY_SRC:-${REPO_ROOT}/boards/${BOARD}/overlay-${BOARD}}"
# shellcheck disable=SC2034  # used by the scripts that source this file
OVERLAY_DST="${CHROMIUMOS_ROOT}/src/overlays/overlay-${BOARD}"

export PATH="${DEPOT_TOOLS}:${PATH}"

# ChromiumOS tools (cros_sdk, repo) need Python 3.11 or newer; Ubuntu 22.04's
# python3 is 3.10. If a newer python3.X is installed, make it python3.
if ! python3 -c 'import sys; sys.exit(sys.version_info < (3, 11))' 2>/dev/null; then
  for _py in python3.13 python3.12 python3.11; do
    if command -v "${_py}" >/dev/null; then
      _shim="${XDG_CACHE_HOME:-${HOME}/.cache}/pinebook-build/bin"
      mkdir -p "${_shim}"
      ln -sfn "$(command -v "${_py}")" "${_shim}/python3"
      export PATH="${_shim}:${PATH}"
      break
    fi
  done
  unset _py _shim
fi

if [[ -t 1 ]]; then
  _c_info=$'\e[1;34m' _c_warn=$'\e[1;33m' _c_err=$'\e[1;31m' _c_ok=$'\e[1;32m' _c_off=$'\e[0m'
else
  _c_info='' _c_warn='' _c_err='' _c_ok='' _c_off=''
fi

info() { printf '%s[INFO]%s %s\n' "${_c_info}" "${_c_off}" "$*"; }
ok()   { printf '%s[ OK ]%s %s\n' "${_c_ok}" "${_c_off}" "$*"; }
warn() { printf '%s[WARN]%s %s\n' "${_c_warn}" "${_c_off}" "$*" >&2; }
die()  { printf '%s[FAIL]%s %s\n' "${_c_err}" "${_c_off}" "$*" >&2; exit 1; }

# run CMD...: print and run a command, or only print it when DRY_RUN=1.
run() {
  printf '%s[ CMD]%s %s\n' "${_c_info}" "${_c_off}" "$*"
  [[ "${DRY_RUN}" == "1" ]] && return 0
  "$@"
}

# start_log NAME: tee everything the calling script prints into OUTPUT_DIR/logs.
start_log() {
  local dir="${OUTPUT_DIR}/logs"
  mkdir -p "${dir}"
  LOG_FILE="${dir}/$1-$(date +%Y%m%d-%H%M%S).log"
  exec > >(tee -a "${LOG_FILE}") 2>&1
  info "Log: ${LOG_FILE}"
}

is_wsl() { grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null; }

# Windows drives mounted under /mnt/<letter> are drvfs/9p: case-insensitive,
# no proper symlinks or permissions, and the ChromiumOS SDK refuses them.
is_windows_mount() {
  local fstype
  fstype="$(stat -f -c %T "$1" 2>/dev/null || true)"
  [[ "$1" =~ ^/mnt/[a-zA-Z](/|$) || "${fstype}" == "v9fs" || "${fstype}" == "9p" ]]
}

# missing MSG: fatal normally, only a warning under DRY_RUN=1.
missing() {
  if [[ "${DRY_RUN}" == "1" ]]; then warn "$* (ignored: DRY_RUN=1)"; else die "$*"; fi
}

need_checkout() {
  [[ -d "${CHROMIUMOS_ROOT}/.repo" ]] \
    || missing "No ChromiumOS checkout at ${CHROMIUMOS_ROOT}. Run build/linux/sync.sh first."
}

need_depot_tools() {
  if ! command -v repo >/dev/null || ! command -v cros_sdk >/dev/null; then
    missing "depot_tools not found at ${DEPOT_TOOLS}. Run build/linux/sync.sh first."
  fi
}

# Path of the image build_image produced for IMAGE_TYPE.
image_path() {
  local name
  case "${IMAGE_TYPE}" in
    base) name=chromiumos_base_image.bin ;;
    dev)  name=chromiumos_image.bin ;;
    test) name=chromiumos_test_image.bin ;;
    *) die "IMAGE_TYPE must be base, dev or test (got: ${IMAGE_TYPE})" ;;
  esac
  printf '%s/src/build/images/%s/latest/%s\n' "${CHROMIUMOS_ROOT}" "${BOARD}" "${name}"
}
