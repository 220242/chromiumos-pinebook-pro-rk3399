#!/bin/bash
# Runs inside the ChromiumOS SDK, called by build.sh's patch stage.
# Usage: patch-image-inner.sh BOARD IMAGE ATOM...
# Installs the board's binary packages for ATOM... into the root file system
# of IMAGE (as build_image would) and redoes the SELinux labels.

set -euo pipefail

board=$1
image=$2
shift 2

root=/tmp/pinebook-patch-root
state=/tmp/pinebook-patch-state
mount_gpt=/mnt/host/source/src/scripts/mount_gpt_image.sh
args=( --board="${board}" --from="$(dirname "${image}")" --image="$(basename "${image}")"
	--rootfs_mountpt="${root}" --stateful_mountpt="${state}" )

"${mount_gpt}" "${args[@]}"
trap '"${mount_gpt}" --unmount "${args[@]}"' EXIT

echo ">>> Installing into the image: $*"
sudo "emerge-${board}" --root="${root}" --root-deps=rdeps --usepkgonly \
	--nodeps --oneshot --jobs=4 "$@"

selinux_config=${root}/etc/selinux/config
if [[ -f ${selinux_config} ]]; then
	selinux_type=$(source "${selinux_config}" && echo "${SELINUXTYPE}")
	file_contexts=${root}/etc/selinux/${selinux_type}/contexts/files/file_contexts
	echo ">>> Relabelling ${root} for SELinux"
	sudo /sbin/setfiles -m -r "${root}" "${file_contexts}" "${root}"
fi
echo ">>> Image patched"
