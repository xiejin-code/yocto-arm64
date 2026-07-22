#!/bin/bash
#
# env.sh - BitBake build environment management script
#
# Usage:
#   ./env.sh start    - Enter the BitBake shell environment
#

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SETUP_NAME="rk3568-wrynose"
SETUP_CONFIG="${PROJECT_DIR}/configurations/rk3568-poky-altcfg-wrynose.conf.json"
BUILD_BASE="${PROJECT_DIR}/bitbake-builds/${SETUP_NAME}"
BUILD_DIR="${BUILD_BASE}/build"
INIT_SCRIPT="${BUILD_DIR}/init-build-env"
OE_CORE_DIR="${BUILD_BASE}/layers/openembedded-core"

case "${1}" in
    start)
        cd "${PROJECT_DIR}" || {
            echo "Error: Could not enter ${PROJECT_DIR}" >&2
            exit 1
        }

        # Initialize git submodules.
        git submodule sync
        git submodule update --init

        if [ ! -f "${SETUP_CONFIG}" ]; then
            echo "Error: Setup configuration not found: ${SETUP_CONFIG}" >&2
            exit 1
        fi

        if [ ! -f "${INIT_SCRIPT}" ]; then
            echo "BitBake environment not initialized, running 'bitbake-setup init'..."
            ./bitbake/bin/bitbake-setup init "${SETUP_CONFIG}" rk3568 \
                --setup-dir-name "${SETUP_NAME}" \
                --non-interactive || {
                echo "Error: 'bitbake-setup init' failed" >&2
                exit 1
            }
        fi

        if [ ! -f "${INIT_SCRIPT}" ]; then
            echo "Error: BitBake setup is incomplete: ${INIT_SCRIPT} was not created" >&2
            exit 1
        fi

        echo "Entering BitBake shell environment..."
        echo "Warning: The fzhub MACHINE is an incomplete RK3568 board skeleton."
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
