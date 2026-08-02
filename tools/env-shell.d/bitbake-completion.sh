#!/bin/bash
# bitbake-completion.sh
# Tab completion for bitbake: recipe names, tasks (-c) and .bb files (-b)
#
# Loaded by tools/bin/env-shell.sh under `bash --rcfile`
# (takes effect automatically after entering the `env.sh start` shell)
#
# Configurable via environment variables:
#   BITBAKE_CACHE_TTL          Cache validity in seconds (default 3600 = 60 min)
#   BITBAKE_COMPLETION_SOURCE  Data source: auto (default) | show | layers
#     auto   : try `bitbake -s` first, fall back to bitbake-layers on failure
#     show   : force `bitbake -s` (includes -native/-nativesdk variants)
#     layers : force `bitbake-layers show-recipes -r --show-variants` (variants)
#
# Cache: ${BUILDDIR}/cache/bitbake-completion-recipes.txt (isolated per build)
# Manual refresh: run `bitbake-completion-refresh` (or `_bitbake_refresh_recipes`)

# Bash only (env-shell.sh is parsed by `bash --rcfile`; this is a safety net)
[ -n "$BASH_VERSION" ] || return 0

# ---- Configuration ----
BITBAKE_RECIPE_CACHE="${BUILDDIR}/cache/bitbake-completion-recipes.txt"
BITBAKE_CACHE_TTL="${BITBAKE_CACHE_TTL:-3600}"
BITBAKE_COMPLETION_SOURCE="${BITBAKE_COMPLETION_SOURCE:-auto}"

# ---- Extract recipe names from `bitbake -s` (includes -native/-nativesdk) ----
# Output: two header lines + "name    version" rows; take col 1, skip headers
_bitbake_recipes_from_show() {
    bitbake -s 2>/dev/null \
        | awk 'NR>2 && $1 ~ /^[A-Za-z0-9_.+-]+$/ {print $1}' \
        | sort -u
}

# ---- Extract names from `bitbake-layers show-recipes` (with variants) ----
# Output: "=== ... ===" title + one name per line; filter non-name lines
_bitbake_recipes_from_layers() {
    bitbake-layers show-recipes -r --show-variants 2>/dev/null \
        | awk '/^[A-Za-z0-9_.+-]+$/ {print $1}' \
        | sort -u
}

# ---- Refresh cache (regenerate the recipe list) ----
_bitbake_refresh_recipes() {
    local cache_dir tmp
    cache_dir="$(dirname "${BITBAKE_RECIPE_CACHE}")"
    mkdir -p "${cache_dir}"
    tmp="${BITBAKE_RECIPE_CACHE}.$$"

    case "${BITBAKE_COMPLETION_SOURCE}" in
        layers)
            _bitbake_recipes_from_layers > "${tmp}"
            ;;
        show)
            _bitbake_recipes_from_show > "${tmp}"
            ;;
        *)  # auto
            _bitbake_recipes_from_show > "${tmp}"
            if [ ! -s "${tmp}" ]; then
                _bitbake_recipes_from_layers > "${tmp}"
            fi
            ;;
    esac

    if [ -s "${tmp}" ]; then
        mv "${tmp}" "${BITBAKE_RECIPE_CACHE}"
    else
        rm -f "${tmp}"
    fi
}

# ---- Read cache (auto-refresh when stale) ----
_bitbake_recipes() {
    if [ ! -f "${BITBAKE_RECIPE_CACHE}" ] \
       || [ $(( $(date +%s) - $(stat -c %Y "${BITBAKE_RECIPE_CACHE}" 2>/dev/null || echo 0) )) -gt "${BITBAKE_CACHE_TTL}" ]; then
        _bitbake_refresh_recipes
    fi
    cat "${BITBAKE_RECIPE_CACHE}" 2>/dev/null
}

# ---- Main completion function ----
_bitbake_completion() {
    local cur prev
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    case "${prev}" in
        -c|--cmd)
            # complete task names
            COMPREPLY=( $(compgen -W "clean cleansstate compile configure devshell do_build do_clean do_compile do_configure do_fetch do_install do_populate_sysroot do_unpack fetch install listtasks populate_sysroot unpack" -- "${cur}") )
            return 0
            ;;
        -b|--file)
            # complete .bb file paths
            COMPREPLY=( $(compgen -f -X '!*.bb' -- "${cur}") )
            return 0
            ;;
    esac

    # complete recipe names
    COMPREPLY=( $(compgen -W "$(_bitbake_recipes)" -- "${cur}") )
}

# ---- Register completion ----
complete -F _bitbake_completion bitbake

# ---- Force refresh helper ----
bitbake-completion-refresh() {
    _bitbake_refresh_recipes
    echo "bitbake completion cache refreshed: ${BITBAKE_RECIPE_CACHE}"
}
