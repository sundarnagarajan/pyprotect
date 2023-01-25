#!/bin/bash
set -eu -o pipefail
SCRIPT_DIR=$(readlink -f "$BASH_SOURCE}")
source "$SCRIPT_DIR"/minimal_manylinux_functions.sh || return 1

function python2_versions() {
    # Outputs path to python executable(s) - one per line
    ( 
        cd /opt/python
        ls -1d cp2* | sort_versions | sed -e 's/^/\/opt\/python\//' -e 's/$/\/bin\/python/'
    )
}

function pypy3_versions() {
    # Outputs path to python executable(s) - one per line
    ( 
        cd /opt/python
        ls -1d pp3* | sort_versions | sed -e 's/^/\/opt\/python\//' -e 's/$/\/bin\/python/'
    )
}

