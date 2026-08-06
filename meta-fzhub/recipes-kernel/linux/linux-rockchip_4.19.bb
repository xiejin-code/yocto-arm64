# Copyright (C) 2020, Rockchip Electronics Co., Ltd
# Released under the MIT license (see COPYING.MIT for the terms)

require recipes-kernel/linux/linux-yocto.inc
require linux-rockchip.inc

inherit local-git

SRCREV = "9789c7416f009b1c7a064241a5f185b368b24732"
SRC_URI = " \
	git://github.com/JeffyCN/mirrors.git;protocol=https;nobranch=1;branch=kernel-4.19-2022_11_23; \
	file://${THISDIR}/files/cgroups.cfg \
	file://${THISDIR}/linux-rockchip_4.19/0001-init-do_mounts.c-Retry-all-fs-after-failed-to-mount-.patch \
	file://${THISDIR}/linux-rockchip_4.19/0002-HACK-drm-rockchip-Force-enable-legacy-cursor-update.patch \
	file://${THISDIR}/linux-rockchip_4.19/0003-HACK-drm-rockchip-Prefer-non-cluster-overlay-planes.patch \
"

LIC_FILES_CHKSUM = "file://COPYING;md5=bbea815ee2795b2f4230826c0c6b8814"

KERNEL_VERSION_SANITY_SKIP = "1"
LINUX_VERSION ?= "4.19"

SRC_URI:append = " ${@bb.utils.contains('IMAGE_FSTYPES', 'ext4', \
		   'file://${THISDIR}/files/ext4.cfg', \
		   '', \
		   d)}"
