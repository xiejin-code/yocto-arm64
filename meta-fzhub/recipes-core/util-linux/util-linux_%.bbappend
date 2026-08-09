# fzhub: 5.10 kernel (linux-libc-headers 5.10-custom) lacks the new mount FD
# APIs that util-linux 2.41 needs: mount_setattr (5.12+) and statmount (6.8+).
# With --enable-libmount-mountfd-support the configure test fails hard, so drop
# the feature. The util-linux recipe itself notes that 5.10.y kernels should use
# the old mount API anyway.
PACKAGECONFIG:class-target:remove = "libmount-mountfd-support"
