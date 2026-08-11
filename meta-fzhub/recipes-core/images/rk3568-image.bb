require recipes-core/images/core-image-minimal.bb

IMAGE_INSTALL += "kernel-modules"

# fzhub: produce a Rockchip-style rootfs.img for the 'rootfs' GPT partition.
#
# IMAGE_FSTYPES selects which rootfs formats the do_image_<fstype> tasks
# generate. 'ext4' is the format used by the rootfs partition in
# parameter.txt; linux-rockchip also appends an ext4 kernel config fragment
# when ext4 is enabled.
IMAGE_FSTYPES += "ext4"

# After every image format has been generated (inside do_image_complete),
# expose a rootfs.img symlink in ${IMGDEPLOYDIR} so the deploy dir contains
# one named image per GPT partition, matching the other .img artifacts
# (uboot.img / boot.img / misc.img / ...).
IMAGE_POSTPROCESS_COMMAND += "deploy_rootfs_img; "

deploy_rootfs_img() {
	# ${IMAGE_BASENAME}-${MACHINE}.rootfs.ext4 is produced by IMAGE_FSTYPES += "ext4"
	ln -sf "${IMAGE_BASENAME}-${MACHINE}.rootfs.ext4" "${IMGDEPLOYDIR}/rootfs.img"
}

#development mode no need passwords
IMAGE_FEATURES += "empty-root-password"