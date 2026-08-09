# rk3568-standalone.bb - Deploy prebuilt standalone partition images
#
# Deploys the prebuilt standalone partition images (oem/recovery/userdata)
# from tools/standaloneImage to ${DEPLOY_DIR_IMAGE}. They correspond to the
# recovery / oem / userdata partitions in the Rockchip GPT parameter table
# (see the rk3568-parameter recipe).
#
# The images are large prebuilt binaries, so they are kept outside the layer
# (in the project's tools/standaloneImage) and referenced by project path
# instead of being shipped inside the layer.

SUMMARY = "Prebuilt standalone partition images (oem/recovery/userdata) for rk3568"
SECTION = "bootloaders"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/COPYING.MIT;md5=3da9cfbcb788c80a0384361b4de20420"

inherit deploy

# Directory holding the prebuilt standalone images
STANDALONE_IMAGE_DIR ?= "${TOPDIR}/../../../tools/standaloneImage"

# Files to deploy (space separated)
STANDALONE_IMAGES ?= "oem.img recovery.img userdata.img"

do_compile() {
	# Verify all sources are present before deploying
	for f in ${STANDALONE_IMAGES}; do
		[ -f "${STANDALONE_IMAGE_DIR}/${f}" ] || bbfatal "${STANDALONE_IMAGE_DIR}/${f} not found"
	done
}

do_deploy() {
	install -d "${DEPLOYDIR}"
	for f in ${STANDALONE_IMAGES}; do
		install -m 0644 "${STANDALONE_IMAGE_DIR}/${f}" "${DEPLOYDIR}/${f}-${PV}"
		ln -sf "${f}-${PV}" "${DEPLOYDIR}/${f}"
	done
}
addtask do_deploy after do_compile before do_build
