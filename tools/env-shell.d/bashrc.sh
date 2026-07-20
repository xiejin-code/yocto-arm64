#!/bin/bash
#
# bashrc.sh - Custom Bash prompt and shell settings
#

# Custom PS1: user@host:path (branch)$
# Green user@host, blue path, yellow git branch
PS1='\[\e[01;32m\]$(__git_ps1 " (YOCTO [%s])" 2>/dev/null) \u@\h:\w\n\$ \[\e[00m\]'

# ============================================================
# Custom git push wrapper
# ============================================================
git() {
    if [[ "$1" == "push" ]]; then
        command git "$@"
        local rc=$?
        if [ $rc -eq 0 ]; then
            echo -e "Push \e[32msuccessful\e[0m!"
        else
            echo -e "Push \e[31mfailed\e[0m!"
        fi
        return $rc
    else
        command git "$@"
    fi
}
