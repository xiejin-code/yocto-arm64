# Copyright (C) 2020, Rockchip Electronics Co., Ltd
# Released under the MIT license (see COPYING.MIT for the terms)

require recipes-kernel/linux-libc-headers/linux-libc-headers.inc

inherit local-git

SRCREV = "f207a103477d8c601d89db381f07246d6942d9d0"
SRC_URI = " \
	git://github.com/JeffyCN/mirrors.git;protocol=https;nobranch=1;branch=kernel-2022_06_27; \
	file://${THISDIR}/linux-libc-headers_4.4-custom/0001-v4l-add-Mediatek-compressed-video-block-format.patch \
	file://${THISDIR}/linux-libc-headers_4.4-custom/0002-videodev2.h-add-V4L2_PIX_FMT_VP9-format.patch \
	file://${THISDIR}/linux-libc-headers_4.4-custom/0003-uapi-fix-linux-if.h-userspace-compilation-errors.patch \
	file://${THISDIR}/linux-libc-headers_4.4-custom/0004-uapi-netlink.h-Add-more-definations-from-upstream.patch \
	file://${THISDIR}/linux-libc-headers_4.4-custom/0005-uapi-ioctls.h-Add-TIOCGPTPEER-from-upstream.patch \
	file://${THISDIR}/linux-libc-headers_4.4-custom/0006-BACKPORT-arm64-Introduce-prctl-options-to-control-th.patch \
	file://${THISDIR}/linux-libc-headers_4.4-custom/0007-netfilter-nft_log-complete-NFTA_LOG_FLAGS-attr-suppo.patch \
	file://${THISDIR}/linux-libc-headers_4.4-custom/0008-netfilter-nft_log-restrict-the-log-prefix-length-to-.patch \
"

# linux-libc-headers.inc defaults to the kernel.org tarball layout
# (${UNPACKDIR}/linux-${PV}); Git fetches unpack to ${UNPACKDIR}/${BP}.
S = "${UNPACKDIR}/${BP}"

LIC_FILES_CHKSUM = "file://COPYING;md5=d7810fab7487fb0aad327b76f1be7cd7"

do_install_armmultilib:prepend() {
	touch ${D}${includedir}/asm/bpf_perf_event.h
}
