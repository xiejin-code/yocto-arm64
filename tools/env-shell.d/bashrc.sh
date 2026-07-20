#!/bin/bash
#
# bashrc.sh - Custom Bash prompt and shell settings
#

# Load Git prompt helper for branch display
#source /usr/share/git/git-prompt.sh 2>/dev/null

# Custom PS1: user@host:path (branch)$
# Green user@host, blue path, yellow git branch
PS1='\[\e[01;32m\]$(__git_ps1 " (YOCTO [%s])" 2>/dev/null) \u@\h:\w\n\$ \[\e[00m\]'
