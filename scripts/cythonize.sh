#!/bin/bash
# Can be fully reused, changing only config.sh
#
set -e -u -o pipefail
PROG_DIR=$(readlink -e $(dirname $0))
SCRIPT_NAME=$(basename $0)
source "$PROG_DIR"/config.sh
source "$PROG_DIR"/common_functions.sh

CYTHON_CMD=$(command -v cython3) || {
    >&2 red "${SCRIPT_NAME}: cython3 command not found"
    >&2 red "${SCRIPT_NAME}: On Debian-like system install package cython3"
    exit 1
}


cd "$PROG_DIR"/../${PY_MODULE}
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

restore_file_ownership ${EXTENSION_NAME}.pyx ${EXTENSION_NAME}.c
