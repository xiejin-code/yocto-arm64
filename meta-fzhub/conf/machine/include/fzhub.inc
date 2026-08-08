require conf/machine/include/rk3568.inc

# fzhub: we don't use the meta-rockchip wic image flow
# (no SPL_BINARY/idbloader deploy, no wic FSTYPE, no rockchip.wks, no extlinux)
SPL_BINARY = ""
IMAGE_FSTYPES:remove = "wic wic.bmap"
WKS_FILE = ""

# fzhub: build and deploy u-boot-rockchip automatically with any image
EXTRA_IMAGEDEPENDS += "virtual/bootloader"
MACHINE_ESSENTIAL_EXTRA_RDEPENDS:remove = "u-boot-extlinux"

# fzhub: kernel — use Rockchip-style boot.img (kernel+dtb packed), drop plain Image
ROCKCHIP_KERNEL_IMAGES = "1"
KERNEL_IMAGETYPE = "boot.img"


