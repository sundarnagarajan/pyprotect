#!/bin/bash
set -e -u -o pipefail
PROG_DIR=$(readlink -e $(dirname $0))
source "$PROG_DIR"/config.sh
CYTHON_CMD=$(command -v cython3) || {
    >&2 echo "cython3 command not found"
    >&2 echo "On Debian-like system install package cython3"
    exit 1
}

PROG_DIR=$(readlink -e $(dirname $0))
SCRIPT_NAME=$(basename $0)

cd "$PROG_DIR"/../pyprotect
TARGET=${EXTENSION_NAME}.c

[[ -f $TARGET ]] && {
    REBUILD_REQUIRED=0
} || {
    REBUILD_REQUIRED=1
}

[[ $REBUILD_REQUIRED -eq 0 ]] && {
    for f in ${EXTENSION_NAME}.pyx *.pxi
    do
        [[ $f -nt $TARGET ]] && {
            >&2 echo "${SCRIPT_NAME}: Newer: $f"
            REBUILD_REQUIRED=1
            break
        }
    done
}

[[ $REBUILD_REQUIRED -eq 0 ]] && {
    >&2 echo "${SCRIPT_NAME}: ${TARGET}: No rebuild required"
    exit 0
}

>&2 echo "${SCRIPT_NAME}: Rebuilding ${TARGET}"
$CYTHON_CMD --3str ${EXTENSION_NAME}.pyx
