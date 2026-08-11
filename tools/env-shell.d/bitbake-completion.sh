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

# ---- Logging ----
_bitbake_log_failure() {
    printf '\033[1;31mFAILURE\033[0m %s\n' "$*" >&2
}

# ---- Extract recipe names from `bitbake -s` (includes -native/-nativesdk) ----
# Output may include BitBake progress lines; only accept rows from the recipe
# table, where the second column is the version field prefixed with ':'.
_bitbake_recipes_from_show() {
    ( set -o pipefail
      bitbake -s \
        | awk '
            /^Recipe Name[[:space:]]+/ { in_recipes = 1; next }
            in_recipes && $1 ~ /^[A-Za-z0-9_.+-]+$/ && $2 ~ /^[0-9]*:/ { print $1 }
        ' \
        | sort -u )
}

# ---- Extract names from `bitbake-layers show-recipes` (with variants) ----
# Output: "=== ... ===" title + one name per line; filter non-name lines
_bitbake_recipes_from_layers() {
    ( set -o pipefail
      bitbake-layers show-recipes -r --show-variants \
        | awk '/^[A-Za-z0-9_.+-]+$/ {print $1}' \
        | sort -u )
}

# ---- Try one data source and explain the result ----
_bitbake_try_recipe_source() {
    local source tmp err status first_error
    source="$1"
    tmp="$2"
    err="${tmp}.${source}.err"

    : > "${tmp}"

    case "${source}" in
        show)
            _bitbake_recipes_from_show > "${tmp}" 2> "${err}"
            ;;
        layers)
            _bitbake_recipes_from_layers > "${tmp}" 2> "${err}"
            ;;
        *)
            BITBAKE_COMPLETION_ERROR="Unknown recipe source '${source}'."
            rm -f "${err}"
            return 1
            ;;
    esac
    status=$?

    if [ "${status}" -ne 0 ]; then
        first_error="$(awk 'NF { print; exit }' "${err}" 2>/dev/null)"
        if [ -n "${first_error}" ]; then
            BITBAKE_COMPLETION_ERROR="Source '${source}' failed with exit status ${status}: ${first_error}"
        else
            BITBAKE_COMPLETION_ERROR="Source '${source}' failed with exit status ${status}."
        fi
        rm -f "${err}"
        return 1
    fi

    if [ ! -s "${tmp}" ]; then
        BITBAKE_COMPLETION_ERROR="Source '${source}' completed but produced no recipe names."
        rm -f "${err}"
        return 1
    fi

    rm -f "${err}"
    BITBAKE_COMPLETION_ERROR=""
    return 0
}

# ---- Refresh cache (regenerate the recipe list) ----
_bitbake_refresh_recipes() {
    local cache_dir tmp
    BITBAKE_COMPLETION_ERROR=""
    cache_dir="$(dirname "${BITBAKE_RECIPE_CACHE}")"
    mkdir -p "${cache_dir}"
    tmp="${BITBAKE_RECIPE_CACHE}.$$"

    case "${BITBAKE_COMPLETION_SOURCE}" in
        layers)
            _bitbake_try_recipe_source layers "${tmp}"
            ;;
        show)
            _bitbake_try_recipe_source show "${tmp}"
            ;;
        *)  # auto
            _bitbake_try_recipe_source show "${tmp}" || \
                _bitbake_try_recipe_source layers "${tmp}"
            ;;
    esac

    if [ -s "${tmp}" ]; then
        mv "${tmp}" "${BITBAKE_RECIPE_CACHE}"
        return 0
    else
        rm -f "${tmp}"
        _bitbake_log_failure "${BITBAKE_COMPLETION_ERROR:-Recipe cache was not updated because all configured sources failed.}"
        return 1
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
    if _bitbake_refresh_recipes; then
        printf 'Bitbake RecipeCache saved: %s\n' "${BITBAKE_RECIPE_CACHE}"
    else
        return 1
    fi
}
