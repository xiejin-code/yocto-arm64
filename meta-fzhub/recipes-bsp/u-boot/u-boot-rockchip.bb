# Copyright (C) 2019, Fuzhou Rockchip Electronics Co., Ltd
# Released under the MIT license (see COPYING.MIT for the terms)

inherit local-git python3-dir

require recipes-bsp/u-boot/u-boot.inc
require recipes-bsp/u-boot/u-boot-common.inc

PROVIDES = "virtual/bootloader"

DEPENDS += "bc-native dtc-native"

PV = "2017.09"

LIC_FILES_CHKSUM = "file://Licenses/README;md5=a2c678cfd4a4d97135585cad908541c6"

SRCREV = "ea524bb895dcc9901cdb667a305dcb67b7dd6744"
SRCREV_rkbin = "08cffc0e233d52a4bbbc5cd18bd3ec12379e56a3"
SRC_URI = " \
	git://github.com/xiejin-code/rk3568-uboot.git;protocol=ssh;branch=main; \
	git://github.com/xiejin-code/rkbin.git;protocol=ssh;branch=main;name=rkbin;destsuffix=rkbin; \
	file://0001-kbuild-use-fmacro-prefix-map-to-make-__FILE__-a-rela.patch \
	file://0002-HACK-Support-python3-for-dtoc.patch \
	file://0003-Revert-Makefile-enable-Werror-option.patch \
	file://bootdelay.cfg \
"

SRCREV_FORMAT = "default_rkbin"

DEPENDS:append = " ${PYTHON_PN}-native"

# Needed for packing BSP u-boot
DEPENDS:append = " coreutils-native ${PYTHON_PN}-pyelftools-native"

do_configure:prepend() {
	# Make sure we use /usr/bin/env ${PYTHON_PN} for scripts
	for s in `grep -rIl python ${S}`; do
		sed -i -e '1s|^#!.*python[23]*|#!/usr/bin/env ${PYTHON_PN}|' $s
	done

	# Support python3
	sed -i -e 's/\(open([^,]*\))/\1, "rb")/' \
		-e 's/print >> \([^,]*\), *\(.*\),*$/print(\2, file=\1)/' \
		-e 's/print \(.*\)$/print(\1)/' \
		${S}/arch/arm/mach-rockchip/make_fit_atf.py

	# Remove unneeded stages from make.sh
	sed -i -e '/^select_tool/d' -e '/^clean/d' -e '/^\t*make/d' -e '/which python2/{n;n;s/exit 1/true/}' ${S}/make.sh

	if [ "x${RK_ALLOW_PREBUILT_UBOOT}" = "x1" ]; then
		# Copy prebuilt images
		if [ -e "${S}/${UBOOT_BINARY}" ]; then
			bbnote "${PN}: Found prebuilt images."
			mkdir -p ${B}/prebuilt/
			mv ${S}/*.bin ${S}/*.img ${B}/prebuilt/
		fi
	fi

	[ ! -e "${S}/.config" ] || make -C ${S} mrproper

	sed -i 's/ found;/ found = NULL;/' ${S}/lib/avb/libavb/avb_slot_verify.c
}

# Generate Rockchip style loader binaries
RK_IDBLOCK_IMG = "idblock.img"
RK_LOADER_BIN = "MiniLoaderAll.bin"
RK_TRUST_IMG = "trust.img"
UBOOT_BINARY = "uboot.img"

do_compile:append() {
	cd ${B}

	if [ -e "${B}/prebuilt/${UBOOT_BINARY}" ]; then
		bbnote "${PN}: Using prebuilt images."
		ln -sf ${B}/prebuilt/*.bin ${B}/prebuilt/*.img ${B}/
	else
		# Prepare needed files
		for d in make.sh scripts configs arch/arm/mach-rockchip; do
			cp -rT ${S}/${d} ${d}
		done

		# Fix rkbin path: rkbin is unpacked to ${S}/../rkbin (sources/rkbin)
        sed -i "s|^RKBIN_TOOLS=.*|RKBIN_TOOLS=$(dirname ${S})/rkbin/tools|" make.sh

		# Pack rockchip loader images
		./make.sh
	fi

	ln -sf *_loader*.bin "${RK_LOADER_BIN}"

	# Generate idblock image
	bbnote "${PN}: Generating ${RK_IDBLOCK_IMG} from ${RK_LOADER_BIN}"
	#boot_merger belongs to rkbin, copy it to build/tools
	cp ${S}/../rkbin/tools/boot_merger ${B}/tools/
	./tools/boot_merger unpack -i "${RK_LOADER_BIN}" -o .

	if [ -f FlashHead.bin ];then
		cat FlashHead.bin FlashData.bin > "${RK_IDBLOCK_IMG}"
	else
		./tools/mkimage -n "${SOC_FAMILY}" -T rksd -d FlashData.bin \
			"${RK_IDBLOCK_IMG}"
	fi

	cat FlashBoot.bin >> "${RK_IDBLOCK_IMG}"
}

do_deploy:append() {
	cd ${B}

	for binary in "${RK_IDBLOCK_IMG}" "${RK_LOADER_BIN}" "${RK_TRUST_IMG}";do
		[ -f "${binary}" ] || continue
		install "${binary}" "${DEPLOYDIR}/${binary}-${PV}"
		ln -sf "${binary}-${PV}" "${DEPLOYDIR}/${binary}"
	done
}
