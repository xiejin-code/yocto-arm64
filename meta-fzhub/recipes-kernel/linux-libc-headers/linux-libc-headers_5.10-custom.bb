# Copyright (C) 2021, Rockchip Electronics Co., Ltd
# Released under the MIT license (see COPYING.MIT for the terms)

require recipes-kernel/linux-libc-headers/linux-libc-headers.inc

inherit local-git

SRCREV = "9ef9403c411abaf4c76738b16d8ebdbc2b411eb6"
SRC_URI = " \
	git://github.com/xiejin-code/rk3568-kernel.git;protocol=ssh;nobranch=1;branch=main; \
"

# linux-libc-headers.inc defaults to the kernel.org tarball layout
# (${UNPACKDIR}/linux-${PV}); Git fetches unpack to ${UNPACKDIR}/${BP}.
S = "${UNPACKDIR}/${BP}"

LIC_FILES_CHKSUM = "file://COPYING;md5=6bc538ed5bd9a7fc9398086aedcd7e46"
