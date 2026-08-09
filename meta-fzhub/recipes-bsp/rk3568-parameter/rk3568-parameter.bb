# rk3568-parameter.bb - Deploy the Rockchip GPT parameter partition table
#
# The parameter file defines the GPT partition layout
# (uboot/misc/boot/recovery/backup/rootfs/oem/userdata) used by RKDevTool
# flashing. It is deployed to ${DEPLOY_DIR_IMAGE} alongside uboot.img /
# boot.img / misc.img.
#
# The recipe is pulled into any image build via
#   EXTRA_IMAGEDEPENDS += "rk3568-parameter"
# in conf/machine/include/fzhub.inc.

SUMMARY = "Rockchip GPT parameter partition table for rk3568"
SECTION = "bootloaders"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/COPYING.MIT;md5=3da9cfbcb788c80a0384361b4de20420"

inherit deploy

# Source parameter file (kept in files/); switch for other variants.
PARAMETER_FILE ?= "parameter-buildroot-fit.txt"

# Deployed filename (Rockchip convention used by RKDevTool).
PARAMETER_IMAGE ?= "parameter.txt"

SRC_URI = "file://${PARAMETER_FILE}"

do_compile() {
	# Parameter table is static text; fail early if the file is missing/empty
	[ -s "${UNPACKDIR}/${PARAMETER_FILE}" ] || bbfatal "${PARAMETER_FILE} is empty or missing"
}

do_deploy() {
	install -d "${DEPLOYDIR}"
	install -m 0644 "${UNPACKDIR}/${PARAMETER_FILE}" "${DEPLOYDIR}/${PARAMETER_IMAGE}-${PV}"
	ln -sf "${PARAMETER_IMAGE}-${PV}" "${DEPLOYDIR}/${PARAMETER_IMAGE}"
}
addtask do_deploy after do_compile before do_build
