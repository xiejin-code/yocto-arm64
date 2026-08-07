# Copyright (C) 2021, Rockchip Electronics Co., Ltd
# Released under the MIT license (see COPYING.MIT for the terms)

require recipes-kernel/linux/linux-yocto.inc
require linux-rockchip.inc

inherit local-git

SRCREV = "9ef9403c411abaf4c76738b16d8ebdbc2b411eb6"
SRC_URI = " \
	git://github.com/xiejin-code/rk3568-kernel.git;protocol=ssh;nobranch=1;branch=main; \
	file://${THISDIR}/files/cgroups.cfg \
	file://${THISDIR}/files/no-werror.cfg \
	file://${THISDIR}/files/remove-non-rockchip-arch-arm64.cfg \
	file://${THISDIR}/linux-rockchip_5.10/0001-init-do_mounts.c-Retry-all-fs-after-failed-to-mount-.patch \
	file://${THISDIR}/linux-rockchip_5.10/0002-HACK-drm-rockchip-Force-enable-legacy-cursor-update.patch \
	file://${THISDIR}/linux-rockchip_5.10/0003-HACK-drm-rockchip-Prefer-non-cluster-overlay-planes.patch \
"

LIC_FILES_CHKSUM = "file://COPYING;md5=6bc538ed5bd9a7fc9398086aedcd7e46"

KERNEL_VERSION_SANITY_SKIP = "1"
LINUX_VERSION ?= "5.10"

SRC_URI:append = " ${@bb.utils.contains('IMAGE_FSTYPES', 'ext4', \
		   'file://${THISDIR}/files/ext4.cfg', \
		   '', \
		   d)}"

# Generated kernel debug sources contain build-time paths in comments.
INSANE_SKIP:${PN}-src += "buildpaths"

do_patch:append() {
	sed -i 's/-I\($(BCMDHD_ROOT)\)/-I$(srctree)\/\1/g' \
		${S}/drivers/net/wireless/rockchip_wlan/rkwifi/bcmdhd/Makefile
}
