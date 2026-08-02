#!/bin/bash
#
# env.sh - Initialize and enter the BitBake build environment
#
# Usage: ./env.sh start [-p proxy]

# Project and generated setup paths.
PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SETUP_NAME="rk3568-wrynose"
SETUP_CONFIG="${PROJECT_DIR}/configurations/rk3568-poky-altcfg-wrynose.conf.json"
BUILD_BASE="${PROJECT_DIR}/bitbake-builds/${SETUP_NAME}"
BUILD_DIR="${BUILD_BASE}/build"
INIT_SCRIPT="${BUILD_DIR}/init-build-env"
UPSTREAM_CONFIG="${BUILD_BASE}/config/config-upstream.json"

# Exit with a consistent error message.
fail() {
    echo "Error: $*" >&2
    exit 1
}

# 'start' must appear somewhere in the args; 'proxy' anywhere enables the
# proxy stack (mihomo + proxy env vars). Order does not matter.
started=0
PROXY_ENABLED=0
for arg in "$@"; do
    case "$arg" in
        start) started=1 ;;
        proxy) PROXY_ENABLED=1 ;;
    esac
done
if [ "$started" != "1" ]; then
    echo "Usage: $0 start [-p proxy]"
    exit 1
fi
export PROXY_ENABLED

# Proxy prerequisite check: if the user asked for proxy but mihomo or its
# config is missing, print a loud, actionable reminder (does NOT abort).
if [ "${PROXY_ENABLED}" = "1" ]; then
    missing=""
    command -v mihomo >/dev/null 2>&1 || missing="${missing}\n  - mihomo not installed (not found in PATH)"
    [ -f /etc/mihomo/config.yaml ] || missing="${missing}\n  - /etc/mihomo/config.yaml does not exist"

    if [ -n "${missing}" ]; then
        red=$'\033[0;31m'; yellow=$'\033[0;33m'; nc=$'\033[0m'
        echo -e "${red}[proxy] Prerequisites missing:${missing}${nc}"
        echo
        echo -e "${yellow}1) Install mihomo (download the latest linux-amd64 from https://github.com/MetaCubeX/mihomo/releases):${nc}"
        echo -e "   wget https://github.com/MetaCubeX/mihomo/releases/latest/download/mihomo-linux-amd64-v1.18.10.gz"
        echo -e "   gunzip mihomo-linux-amd64-v1.18.10.gz"
        echo -e "   sudo mv mihomo-linux-amd64-v1.18.10 /usr/local/bin/mihomo && sudo chmod +x /usr/local/bin/mihomo"
        echo
        echo -e "${yellow}2) Generate the config from your subscription with sub2clash.py:${nc}"
        echo -e "   python3 ${PROJECT_DIR}/tools/bin/sub2clash.py 'https://<your-subscription-url>' -o ${PROJECT_DIR}/mihomo-config.yaml -c"
        echo -e "   or manually: sudo mkdir -p /etc/mihomo && sudo cp ${PROJECT_DIR}/mihomo-config.yaml /etc/mihomo/config.yaml"
        echo
    fi
fi

# Prepare the project and BitBake submodule.
cd "${PROJECT_DIR}" || fail "Could not enter ${PROJECT_DIR}"

git submodule sync || fail "Could not synchronize Git submodules"
git submodule update --init || fail "Could not initialize Git submodules"
[ -f "${SETUP_CONFIG}" ] || fail "Setup configuration not found: ${SETUP_CONFIG}"

# Generate the setup on the first run, or update it when its JSON changes.
if [ ! -f "${INIT_SCRIPT}" ]; then
    echo "BitBake environment not initialized, running 'bitbake-setup init'..."
    ./bitbake/bin/bitbake-setup init "${SETUP_CONFIG}" rk3568 \
        --setup-dir-name "${SETUP_NAME}" \
        --non-interactive ||
        fail "'bitbake-setup init' failed"
else
    python3 "${PROJECT_DIR}/tools/bin/compare-setup-config.py" \
        "${SETUP_CONFIG}" "${UPSTREAM_CONFIG}"
    case "$?" in
        0)
            ;;
        1)
            echo "Setup configuration changed, running 'bitbake-setup update'..."
            ./bitbake/bin/bitbake-setup update \
                --setup-dir "${BUILD_BASE}" \
                --update-bb-conf yes ||
                fail "'bitbake-setup update' failed"
            ;;
        *)
            fail "Could not compare setup configurations"
            ;;
    esac
fi

# Validate the generated setup and refresh source links.
[ -f "${INIT_SCRIPT}" ] ||
    fail "BitBake setup is incomplete: ${INIT_SCRIPT} was not created"
python3 "${PROJECT_DIR}/tools/bin/sync-source-links.py" \
    "${SETUP_CONFIG}" "${BUILD_BASE}/layers" "${PROJECT_DIR}" ||
    fail "Could not synchronize source links"

echo "Entering BitBake shell environment..."
echo "Warning: The fzhub MACHINE is an incomplete RK3568 board skeleton."
echo "Type 'exit' or press Ctrl+D to quit"

# Load the OpenEmbedded environment and enter an interactive shell.
cd "${BUILD_BASE}/layers/openembedded-core" ||
    fail "Could not enter the openembedded-core source directory"
set -- "${BUILD_DIR}"
. ./oe-init-build-env || fail "Could not initialize the BitBake environment"

exec /bin/bash --rcfile "${PROJECT_DIR}/tools/bin/env-shell.sh" -i
