#!/bin/bash
#
set -e -u -o pipefail
PROG_DIR=$(readlink -f $(dirname $0))
SCRIPT_NAME=$(basename $0)
source "$PROG_DIR"/common_functions.sh

echo "${SCRIPT_NAME}: Running on $(distro_name) in ${PROG_DIR}"

[[ -z "${EXTENSION_NAME:-}" ]] && {
    >&2 echo "${SCRIPT_NAME}: Not using C-extension"
    exit 0
}
[[ "${CYTHONIZE_REQUIRED:-}" != "yes" ]] && {
    >&2 echo "${SCRIPT_NAME}: C-extension does not require cython"
    exit 0
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
            blue "${SCRIPT_NAME}: Newer: $f"
            REBUILD_REQUIRED=1
            break
        }
    done
}

[[ $REBUILD_REQUIRED -eq 0 ]] && {
    >&2 echo "${SCRIPT_NAME}: ${TARGET}: No rebuild required"
    exit 0
}

[[ -z "${CYTHON3_PROG_NAME:-}" ]] && {
    >&2 red "${SCRIPT_NAME}: CYTHON3_PROG_NAME not set in config.sh"
    exit 1
}
CYTHON_CMD=$(command -v $(basename $CYTHON3_PROG_NAME)) || {
    >&2 red "${SCRIPT_NAME}: cython command not found: $CYTHON3_PROG_NAME"
    >&2 red "${SCRIPT_NAME}: On Debian-like system install package cython3"
    exit 1
}

EXISTING_CYTHON_VER=$($CYTHON3_PROG_NAME --version 2>&1 | cut -d' ' -f3)
[[ -n "${CYTHON3_MIN_VER:-}" ]] && {
    [[ -z "${EXISTING_CYTHON_VER:-}" ]] && {
        >&2 red "${SCRIPT_NAME}: Warning: could not get existing version of $(basename $CYTHON_CMD)"
    }
}
[[ -z "${CYTHON3_MIN_VER:-}" ]] && {
    blue "${SCRIPT_NAME}: Warning: CYTHON3_MIN_VER not set in config.sh"
}
[[ -n "${EXISTING_CYTHON_VER:-}" && -n "${CYTHON3_MIN_VER:-}" ]] && {
    need_minimum_version $EXISTING_CYTHON_VER $CYTHON3_MIN_VER cython || exit 1
}


>&2 echo "${SCRIPT_NAME}: Rebuilding ${TARGET} using $EXISTING_CYTHON_VER"
$CYTHON_CMD --3str ${EXTENSION_NAME}.pyx

restore_file_ownership ${EXTENSION_NAME}.pyx ${EXTENSION_NAME}.c
