#!/bin/bash


function red() {
    # Prints arguments in bold red
    local ANSI_ESC=$(printf '\033')
    local ANSI_RS="${ANSI_ESC}[0m"    # reset
    local ANSI_HC="${ANSI_ESC}[1m"    # hicolor
    local ANSI_FRED="${ANSI_ESC}[31m" # foreground red

    [[ -t 2 ]] && {
        echo -e "${ANSI_RS}${ANSI_HC}${ANSI_FRED}$@${ANSI_RS}"
    } || {
        echo -e "$@"
    }
}


[[ -f /usr/local/bin/MANYLINUX_IMAGE ]] || {
    >&2 red "Not running on manylinux prepared image"
    return 1
}
MANYLINUX_IMAGE=$(cat /usr/local/bin/MANYLINUX_IMAGE)
readonly MANYLINUX_IMAGE


function sort_versions() {
    # manylinux1 (Centos 5.1) has sort from coreutils 5.97 and does not support '-V'
    # So in manylinux1 this is not strictly doing version sort
    # Reads stdin, writes stdout
    [[ $MANYLINUX_IMAGE = "manylinux1" ]] && {
        sort -n
    } || {
        sort -V
    }
}

function python2_versions() {
    # Outputs path to python executable(s) - one per line
    ls -1d /opt/python/cp2*/bin/python | sort_versions
}

function python3_versions() {
    # Outputs path to python executable(s) - one per line
    ls -1d /opt/python/cp3*/bin/python | sort_versions
}

function pypy3_versions() {
    # Outputs path to python executable(s) - one per line
    ls -1d /opt/python/pp3*/bin/python | sort_versions
}

function python3_latest_version() {
    # Outputs path to python executable - single one
    # Used to install twine, maybe other system-level packages using pip
    python3_versions | tail -1
}

