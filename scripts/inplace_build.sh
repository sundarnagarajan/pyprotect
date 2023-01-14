#!/bin/bash
# Can be fully reused, changing only config.sh
#
# Expects Python basename (python2 | python3 | pypy3 | pypy) as first argument

set -e -u -o pipefail
PROG_DIR=$(readlink -f $(dirname $0))
SCRIPT_NAME=$(basename $0)
source "$PROG_DIR"/common_functions.sh

function build_1_in_place() {
    # $1: PYVER - guaranteed to be in TAG_PYVER and have valid image in TAG_IMAGE
    local pyver=$1

    # Disable pip warnings that are irrelevant here
    export PIP_DISABLE_PIP_VERSION_CHECK=1
    export PIP_NO_PYTHON_VERSION_WARNING=1
    export PIP_ROOT_USER_ACTION=ignore

    # Set CFLAGS to optimize further
    export CFLAGS="-O3"
    # Set LDFLAGS to automatically strip .so
    export LDFLAGS=-s

    cd "$PROG_DIR"/..
    PYTHON_BASENAME=${TAG_PYVER[$pyver]}
    PYTHON_CMD=$(command_must_exist ${PYTHON_BASENAME}) || {
        >&2 red "$pyver : python command not found: $PYTHON_BASENAME"
        return 1
    }
    # Check if .so has to be rebuilt
    PY_CODE='
import sys
import sysconfig
if sys.version_info.major == 2:
    CONFIG_KEY = "SO"
else:
    CONFIG_KEY = "EXT_SUFFIX"

print(sysconfig.get_config_var(CONFIG_KEY) or "");
'
    SUFFIX=$($PYTHON_CMD -c "$PY_CODE")
    [[ -z "$SUFFIX" ]] && SUFFIX=".so"
    TARGET="${PY_MODULE}/${EXTENSION_NAME}${SUFFIX}"
    [[ "$SUFFIX" = ".so" ]] && {
        TARGET_BASENAME=$(basename "$TARGET" )
    } || {
        TARGET_BASENAME=$(basename "$TARGET" | sed -e 's/^protected\.//')
    }
    [[ -f "$TARGET" ]] && REBUILD_REQUIRED=0 || REBUILD_REQUIRED=1
    [[ $REBUILD_REQUIRED -eq 0 ]] && {
        [[ "$SRC" -nt "$TARGET" ]] && REBUILD_REQUIRED=1
    }
    [[ $REBUILD_REQUIRED -eq 0 ]] && {
        >&2 echo "${SCRIPT_NAME}: ${TARGET_BASENAME}: No rebuild required"
        return 0
    }
    "${CLEAN_BUILD_SCRIPT}"
    echo "Building ${TARGET_BASENAME} using $PYTHON_BASENAME setup.py build_ext --inplace"
    hide_output_unless_error $PYTHON_CMD setup.py build_ext --inplace || {
        "${CLEAN_BUILD_SCRIPT}"
        return 1
    }
    restore_file_ownership ${PY_MODULE}/${EXTENSION_NAME}.pyx "$TARGET"
    "${CLEAN_BUILD_SCRIPT}"
}


CLEAN_BUILD_SCRIPT="${PROG_DIR}"/clean_build.sh
CYTHONIZE_SCRIPT="${PROG_DIR}"/cythonize.sh
SRC="${PY_MODULE}/${EXTENSION_NAME}.c"
[[ -f "$SRC" ]] || {
    $CYTHONIZE_SCRIPT || {
        # Could fail if cython3 was not found in this container
        >&2 red "C source not found: ${SRC}. Running cythonize.sh failed"
        exit 1
    }
}

# This script does not launch docker containers
VALID_PYVER=$(process_std_cmdline_args no yes $@)

for p in $VALID_PYVER
do
    build_1_in_place $p || continue
done
