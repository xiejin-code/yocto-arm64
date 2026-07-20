#!/bin/bash
#
# env.sh - BitBake build environment management script
#
# Usage:
#   ./env.sh start    - Enter the BitBake shell environment
#

BUILD_BASE="${PWD}/bitbake-builds/poky-wrynose-poky-distro_poky-altcfg-machine_genericarm64"
BUILD_DIR="${BUILD_BASE}/build"
INIT_SCRIPT="${BUILD_DIR}/init-build-env"
OE_CORE_DIR="${BUILD_BASE}/layers/openembedded-core"

case "${1}" in
    start)
        # Initialize git submodules.
        git submodule sync
        git submodule update --init

        if [ ! -f "${INIT_SCRIPT}" ]; then
            echo "BitBake environment not initialized, running 'bitbake-setup init'..."
            ./bitbake/bin/bitbake-setup init poky poky machine/genericarm64 distro/poky-altcfg --non-interactive || {
                echo "Error: 'bitbake-setup init' failed" >&2
                exit 1
            }
        fi

        echo "Entering BitBake shell environment..."
        echo "Type 'exit' or press Ctrl+D to quit"

        # Save original directory, source the init script after entering OE Core directory
        cd "${OE_CORE_DIR}" || {
            echo "Error: Could not enter ${OE_CORE_DIR}" >&2
            exit 1
        }

        # Set build directory arguments, consistent with init-build-env logic
        set -- "${BUILD_DIR}"
        . ./oe-init-build-env

        # Start an interactive subshell with the BitBake environment, using custom rcfile
        # BUILDDIR is already set by oe-init-build-env.
        exec /bin/bash --rcfile "${BUILDDIR}/../../../tools/bin/env-shell.sh" -i
        ;;

    *)
        echo "Usage: $0 {start}"
        echo ""
        echo "Commands:"
        echo "  start    Enter the BitBake shell build environment"
        exit 1
        ;;
esac
