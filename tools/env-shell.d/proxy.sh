#!/bin/bash
# proxy.sh - automatically enable HTTP proxy for bitbake/git when mihomo is running
#
# Loaded by tools/bin/env-shell.sh (bash --rcfile) after oe-init-build-env.
# Detects mihomo on 127.0.0.1:7890; if present, exports proxy env vars so
# bitbake fetches and any child process go through it. Otherwise just warns.

# Only run when the proxy stack is enabled via `env.sh start proxy`
[ "${PROXY_ENABLED:-0}" = "1" ] || return 0

MIHOMO_ADDR="127.0.0.1"
MIHOMO_PORT="${MIHOMO_PORT:-7890}"

if timeout 1 bash -c "echo > /dev/tcp/${MIHOMO_ADDR}/${MIHOMO_PORT}" 2>/dev/null; then
    export http_proxy="http://${MIHOMO_ADDR}:${MIHOMO_PORT}"
    export https_proxy="http://${MIHOMO_ADDR}:${MIHOMO_PORT}"
    export HTTP_PROXY="${http_proxy}"
    export HTTPS_PROXY="${https_proxy}"
    export no_proxy="localhost,127.0.0.1,::1,${no_proxy:-}"
    export NO_PROXY="${no_proxy}"
    echo "[proxy] enabled: http://${MIHOMO_ADDR}:${MIHOMO_PORT}"
else
    echo "[proxy] mihomo not running on ${MIHOMO_ADDR}:${MIHOMO_PORT} - proxy NOT set"
fi
