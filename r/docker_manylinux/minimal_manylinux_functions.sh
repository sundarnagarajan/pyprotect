#!/bin/bash
set -eu -o pipefail

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

# Start with SOME CPython 3.x version
LATEST_PYTHON3_CMD=$(ls -1d /opt/python/cp3*/bin/python | LC_ALL=C sort -n | tail -1)

function sort_versions() {
    # Reads stdin, writes stdout
    # Reads one version per line, writes one version per line
    local PY_CODE='
import sys
try:
    from packaging.version import parse as verfn
except:
    from distutils.version import LooseVersion as verfn

l = []
while True:
    x = sys.stdin.readline()
    if not x:
        break
    x = x.rstrip("\n")
    l.append(x)

# If the list contains proper numeric versions, use verfn
# Otherwise perform regular sort
try:
    l.sort(key=verfn)
except:
    l.sort()
print("\n".join(l))
'
    $LATEST_PYTHON3_CMD -c "$PY_CODE"
    return 0
}

function python3_versions() {
    # Outputs path to python executable(s) - one per line
    ( 
        cd /opt/python
        ls -1d cp3* | sort_versions | sed -e 's/^/\/opt\/python\//' -e 's/$/\/bin\/python/'
    )
}

function python3_latest_version() {
    # Outputs path to python executable - single one
    # Used to install twine, maybe other system-level packages using pip
    # Uses 'sort -n', rather than 'sort -V' to be universally compatible
    python3_versions | tail -1
}

# Update LATEST_PYTHON3_CMD using sort_versions
LATEST_PYTHON3_CMD=$(python3_latest_version)
readonly LATEST_PYTHON3_CMD
