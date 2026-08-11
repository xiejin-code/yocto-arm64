# fzhub: tune meta-oe's android-tools (5.1.1.r37) for the RK3568 board.
#
# 1. Only build/install adbd on the target. adb / fastboot / mkbootimg /
#    ext4_utils are host-side tooling not used on the board - this trims
#    build time and rootfs size. (Main package android-tools will then be
#    nearly empty; that is expected.)
# 2. Upstream android-tools-adbd.service has
#       ConditionPathExists=/etc/usb-debugging-enabled
#    so adbd would never start without that marker. Create it here so the
#    daemon auto-starts on boot. (Note: this is /etc/, not the /var/ marker
#    the Rockchip conf recipe used.)
# 3. Prefer android-tools-conf-configfs (ConfigFS gadget + systemd drop-in
#    that brings up the USB gadget) over the legacy android-tools-conf
#    (which only installs one android-gadget-setup script).

# Build adbd for the target. Adb for host use.
TOOLS:class-target = "adb adbd"

do_install:append:class-target() {
    install -d ${D}${sysconfdir}
    # Satisfy ConditionPathExists in android-tools-adbd.service
    touch ${D}${sysconfdir}/usb-debugging-enabled
}