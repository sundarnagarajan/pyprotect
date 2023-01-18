#!/bin/bash
#
# Expects Python basename (python2 | python3 | pypy3 | pypy) as first argument

set -e -u -o pipefail
PROG_DIR=$(readlink -f $(dirname $0))
SCRIPT_NAME=$(basename $0)
source "$PROG_DIR"/common_functions.sh

function cleanup() {
    # Cleans up RELOCATED_DIR if set and present
    [[ -n $(declare -p RELOCATED_DIR 2>/dev/null) && -n "${RELOCATED_DIR}+_"  && -d "${RELOCATED_DIR}" ]] && {
        echo "Removing RELOCATED_DIR: $RELOCATED_DIR"
        rm -rf "$RELOCATED_DIR"
    }
}

function relocate() {
    # Relocates DOCKER_MOUNTPOINT to a temp dir under /tmp
    # and sets PROG_DIR to ${NEW_TMP_DIR}/scripts
    # Echoes new tmp dir location to stdout

    local NEW_TMP_DIR=$(mktemp -d -p /tmp)
    local old_top_dir=$(readlink -f "${PROG_DIR}/..")
    # We copy all non-hidden files
    cp -a "$old_top_dir"/* ${NEW_TMP_DIR}/
    # Clean out .so files under $PY_MODULE
    rm -f ${NEW_TMP_DIR}/${PY_MODULE}/*.so
    echo -n ${NEW_TMP_DIR}
}

function build_1_in_place_and_test() {
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

    echo "${SCRIPT_NAME}: build_1_in_place_and_test: Running in $PROG_DIR"
    cd "$PROG_DIR"/..
    local PYTHON_BASENAME=${TAG_PYVER[$pyver]}
    local PYTHON_CMD=$(command_must_exist ${PYTHON_BASENAME}) || {
        >&2 red "$pyver : python command not found: $PYTHON_BASENAME"
        return 1
    }
    [[ -z "$PYTHON_CMD" ]] && {
        >&2 red "$pyver : python command not found: $PYTHON_BASENAME"
        return 1
    }
    echo "${SCRIPT_NAME}: Building for $pyver using $PYTHON_CMD"
    # Check if .so has to be rebuilt
    local PY_CODE='
import sys
import sysconfig
if sys.version_info.major == 2:
    CONFIG_KEY = "SO"
else:
    CONFIG_KEY = "EXT_SUFFIX"

print(sysconfig.get_config_var(CONFIG_KEY) or "");
'
    local SUFFIX=$($PYTHON_CMD -c "$PY_CODE")
    [[ -z "$SUFFIX" ]] && SUFFIX=".so"
    local TARGET="${PY_MODULE}/${EXTENSION_NAME}${SUFFIX}"
    local TARGET_BASENAME=""
    [[ "$SUFFIX" = ".so" ]] && {
        TARGET_BASENAME=$(basename "$TARGET" )
    } || {
        TARGET_BASENAME=$(basename "$TARGET" | sed -e 's/^protected\.//')
    }
    local REBUILD_REQUIRED=0
    [[ -f "$TARGET" ]] && REBUILD_REQUIRED=0 || REBUILD_REQUIRED=1
    [[ $REBUILD_REQUIRED -eq 0 ]] && {
        [[ "$SRC" -nt "$TARGET" ]] && REBUILD_REQUIRED=1
    }
    # PY2 Extension may be present but be incmpatible with chosen distro / platform
    [[ $REBUILD_REQUIRED -eq 0 && $SUFFIX = ".so" ]] && {
        local incompatible=0
        ldd "$TARGET" 1>/dev/null 2>&1 || incompatible=1
        [[ $incompatible -eq 0 ]] && {
            [[ $(ldd "$TARGET" 2>/dev/null | awk -F' => ' '$2 == "not found" {print $1}' | wc -l) -eq 0 ]] || incompatible=1
        }
        [[ $incompatible -ne 0 ]] && {
            >&2 echo "${SCRIPT_NAME}: ${TARGET_BASENAME}: Rebuilding because of incompatibility"
            REBUILD_REQUIRED=1
        }
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
    "${PROG_DIR}"/run_func_tests.sh $pyver
}


[[ -z "${EXTENSION_NAME:-}" ]] && {
    >&2 echo "${SCRIPT_NAME}: Not using C-extension"
    exit 0
}

echo "Running in $(distro_name)"

running_in_docker && {
    # relocate and chdir
    RELOCATED_DIR=$(relocate)
    trap cleanup 0 1 2 3 15
    PROG_DIR=${RELOCATED_DIR}/scripts
}
cd "$PROG_DIR"

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
    build_1_in_place_and_test $p || continue
done

