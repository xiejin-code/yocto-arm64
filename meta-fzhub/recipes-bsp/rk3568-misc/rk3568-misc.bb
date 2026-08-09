# rk3568-misc.bb - Generate the Rockchip/Android 'misc' partition image
#
# Produces misc.img (the Android misc partition) which Rockchip's bootloader
# reads to decide e.g. whether to boot into recovery. It is deployed to
# ${DEPLOY_DIR_IMAGE} so it can be flashed alongside uboot.img / boot.img.
#
# The recipe is pulled into any image build via
#   EXTRA_IMAGEDEPENDS += "rk3568-misc"
# in conf/machine/include/fzhub.inc.

SUMMARY = "Generate the Android 'misc' partition image for rk3568"
SECTION = "bootloaders"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/COPYING.MIT;md5=3da9cfbcb788c80a0384361b4de20420"

inherit deploy

SRC_URI = "file://mk-misc.sh"

# Content written into the misc partition. Empty = blank misc image.
# mk-misc.sh writes "boot-recovery" at offset 16K for COMMAND="recovery".
MISC_COMMAND ?= ""

do_compile() {
	bash "${UNPACKDIR}/mk-misc.sh" "${B}/misc.img" ${MISC_COMMAND}
}

do_deploy() {
	install -d "${DEPLOYDIR}"
	install -m 0644 "${B}/misc.img" "${DEPLOYDIR}/misc.img-${PV}"
	ln -sf "misc.img-${PV}" "${DEPLOYDIR}/misc.img"
}
addtask do_deploy after do_compile before do_build
