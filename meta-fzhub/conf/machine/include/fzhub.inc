require conf/machine/include/rk3568.inc

# fzhub: we don't use the meta-rockchip wic image flow
# (no SPL_BINARY/idbloader deploy, no wic FSTYPE, no rockchip.wks, no extlinux)
SPL_BINARY = ""
IMAGE_FSTYPES:remove = "wic wic.bmap"
WKS_FILE = ""
MACHINE_ESSENTIAL_EXTRA_RDEPENDS:remove = "u-boot-extlinux"



