# Copyright 2026 The chromiumos-pinebook-pro-rk3399 Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

DESCRIPTION="Firmware for the AMPAK AP6256 (Broadcom BCM43456) Wi-Fi/Bluetooth module"
HOMEPAGE="https://github.com/armbian/firmware"

# Pinned Armbian firmware commit (2026-09-10).
COMMIT="2a9e1c19460401443267926181191d57e3ff175d"
BASE_URI="https://raw.githubusercontent.com/armbian/firmware/${COMMIT}/brcm"
FILES=(
	brcmfmac43456-sdio.bin
	brcmfmac43456-sdio.clm_blob
	brcmfmac43456-sdio.txt
	BCM4345C5.hcd
)
SRC_URI=""
for f in "${FILES[@]}"; do
	SRC_URI+=" ${BASE_URI}/${f} -> ${P}-${f}"
done

LICENSE="linux-fw-redistributable no-source-code"
SLOT="0"
KEYWORDS="*"
RESTRICT="binchecks strip"

S="${WORKDIR}"

src_unpack() {
	:
}

src_install() {
	insinto /lib/firmware/brcm
	local f
	for f in "${FILES[@]}"; do
		newins "${DISTDIR}/${P}-${f}" "${f}"
	done
	# brcmfmac looks for <chip>.<board compatible>.txt first, then the
	# generic name; hci_bcm does the same for the Bluetooth patch file.
	dosym brcmfmac43456-sdio.txt \
		/lib/firmware/brcm/brcmfmac43456-sdio.pine64,pinebook-pro.txt
	dosym BCM4345C5.hcd /lib/firmware/brcm/BCM4345C5.pine64,pinebook-pro.hcd
}
