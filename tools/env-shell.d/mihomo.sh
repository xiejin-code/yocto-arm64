#!/bin/bash
# mihomo.sh - start mihomo when entering the build env, stop it on exit
#
# Loaded by tools/bin/env-shell.sh (bash --rcfile). Starts mihomo if nothing is
# listening on 127.0.0.1:7890 yet; records the PID of the instance started by
# THIS shell, and stops only that instance via an EXIT trap when the shell exits.
#
# Other shells/terminals that find the port already open will simply reuse the
# running instance and will NOT stop it on exit (no PID file for them).

# Only run when the proxy stack is enabled via `env.sh start proxy`
[ "${PROXY_ENABLED:-0}" = "1" ] || return 0

MIHOMO_ADDR="127.0.0.1"
MIHOMO_PORT="${MIHOMO_PORT:-7890}"
MIHOMO_BIN="$(command -v mihomo)"
# Per-build state dir: a dedicated subdir inside this build's TMPDIR
# (build/tmp/mihomo). Falls back to /tmp/mihomo if TMPDIR is not set.
MIHOMO_DIR="${TMPDIR:-/tmp}/mihomo"
MIHOMO_PIDFILE="${MIHOMO_DIR}/mihomo-env-$$.pid"
MIHOMO_STAMP="$(date +%Y%m%d-%H%M%S)"
MIHOMO_LOGFILE="${MIHOMO_DIR}/mihomo-env-${MIHOMO_STAMP}-$$.log"
mkdir -p "${MIHOMO_DIR}"

# ANSI colors for clear success/failure feedback
C_GREEN=$'\033[0;32m'
C_RED=$'\033[0;31m'
C_YELLOW=$'\033[0;33m'
C_NC=$'\033[0m'

port_listening() {
    timeout 1 bash -c "echo > /dev/tcp/${MIHOMO_ADDR}/${MIHOMO_PORT}" 2>/dev/null
}

if [ -z "${MIHOMO_BIN}" ]; then
    echo "${C_RED}[mihomo] binary not found in PATH - skip${C_NC}"
elif port_listening; then
    echo "${C_YELLOW}[mihomo] already running on ${MIHOMO_ADDR}:${MIHOMO_PORT} - reuse${C_NC}"
else
    # redirect mihomo's own logs to a file so the terminal stays clean
    "${MIHOMO_BIN}" -d /etc/mihomo -f /etc/mihomo/config.yaml > "${MIHOMO_LOGFILE}" 2>&1 &
    echo $! > "${MIHOMO_PIDFILE}"
    # wait up to ~10s for the port to come up
    for _ in {1..20}; do
        port_listening && break
        sleep 0.5
    done
    if port_listening; then
        echo "${C_GREEN}[mihomo] started (pid $(cat "${MIHOMO_PIDFILE}"))${C_NC}"
        # keep only the 3 most recent logs, drop older ones
        ls -1t "${MIHOMO_DIR}"/mihomo-env-*.log 2>/dev/null | tail -n +4 | xargs -r rm -f
    else
        echo "${C_RED}[mihomo] FAILED to start - see log: ${MIHOMO_LOGFILE}${C_NC}"
        tail -n 3 "${MIHOMO_LOGFILE}" 2>/dev/null | sed 's/^/    /'
        rm -f "${MIHOMO_PIDFILE}"
    fi
fi

_mihomo_cleanup() {
    if [ -f "${MIHOMO_PIDFILE}" ]; then
        local pid
        pid="$(cat "${MIHOMO_PIDFILE}")"
        echo "${C_YELLOW}[mihomo] stopping (pid ${pid})${C_NC}"
        kill "${pid}" 2>/dev/null
        rm -f "${MIHOMO_PIDFILE}"
    fi
}
trap _mihomo_cleanup EXIT
