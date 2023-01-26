#!/bin/bash
set -e -u -o pipefail
PROG_DIR=$(readlink -f $(dirname $0))
SCRIPT_NAME=$(basename $0)
source "$PROG_DIR"/common_functions.sh

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

    [[ $VERBOSITY -lt 5 ]] || echo "${SCRIPT_NAME}: build_1_in_place_and_test: Running in $PROG_DIR"
    local PYTHON_BASENAME=${TAG_PYVER[$pyver]}
    local PYTHON_CMD=$(command_must_exist ${PYTHON_BASENAME}) || {
        >&2 red "${SCRIPT_NAME}(${FUNCNAME[0]}): $pyver : python command not found: $PYTHON_BASENAME"
        return 1
    }
    [[ -z "$PYTHON_CMD" ]] && {
        >&2 red "${SCRIPT_NAME}(${FUNCNAME[0]}): $pyver : python command not found: $PYTHON_BASENAME"
        return 1
    }
    [[ $VERBOSITY -lt 3 ]] || echo "${SCRIPT_NAME}: Building for $pyver using $PYTHON_CMD"
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
            [[ $VERBOSITY -lt 3 ]] || blue "${SCRIPT_NAME}: ${TARGET_BASENAME}: Rebuilding because of incompatibility"
            REBUILD_REQUIRED=1
        }
    }
    [[ $REBUILD_REQUIRED -eq 0 ]] && {
        [[ $VERBOSITY -lt 4 ]] || >&2 echo "${SCRIPT_NAME}: ${TARGET_BASENAME}: No rebuild required"
        "${CLEAN_BUILD_SCRIPT}"
        "${PROG_DIR}"/run_func_tests.sh $pyver
        return 0
    }
    "${CLEAN_BUILD_SCRIPT}"
    [[ $VERBOSITY -lt 3 ]] || echo "Building ${TARGET_BASENAME} using $PYTHON_BASENAME setup.py build_ext --inplace"
    hide_output_unless_error $PYTHON_CMD setup.py build_ext --inplace || {
        "${CLEAN_BUILD_SCRIPT}"
        return 1
    }
    [[ $VERBOSITY -lt 4 ]] || echo "${SCRIPT_NAME}: Built target: $TARGET"
    restore_file_ownership ${PY_MODULE}/${EXTENSION_NAME}.pyx "$TARGET"
    "${PROG_DIR}"/run_func_tests.sh $pyver
    "${CLEAN_BUILD_SCRIPT}"
}


# ------------------------------------------------------------------------
# Actual script starts after this
# ------------------------------------------------------------------------

[[ $VERBOSITY -lt 2 ]] || echo "${SCRIPT_NAME}: Running in $(distro_name) as $(id -un)"
[[ -z "${EXTENSION_NAME:-}" ]] && {
    [[ $VERBOSITY -lt 3 ]] || >&2 echo "${SCRIPT_NAME}: Not using C-extension"
    exit 0
}
var_empty __RELOCATED_DIR || {
    PROG_DIR="$__RELOCATED_DIR"/${SCRIPTS_DIR}
    PROG_DIR=$(readlink -f "$PROG_DIR")
} && {
    running_in_docker && {
        relocate_source_dir
        PROG_DIR="$__RELOCATED_DIR"/${SCRIPTS_DIR}
        PROG_DIR=$(readlink -f "$PROG_DIR")
    }
}
cd "$PROG_DIR"/../..
[[ $VERBOSITY -lt 5 ]] ||  echo "${SCRIPT_NAME}: Running in $(pwd)"

CLEAN_BUILD_SCRIPT="${PROG_DIR}"/clean_build.sh
CYTHONIZE_SCRIPT="${PROG_DIR}"/cythonize_inplace.sh
SRC="${PY_MODULE}/${EXTENSION_NAME}.c"
[[ -f "$SRC" ]] || {
    $CYTHONIZE_SCRIPT || {
        # Could fail if cython3 was not found in this container
        >&2 red "${SCRIPT_NAME}: C source not found: ${SRC}. Running $(basename $CYTHONIZE_SCRIPT) failed"
        exit 1
    }
}

# This script does not launch docker containers
VALID_PYVER=$(process_std_cmdline_args no yes $@)

for p in $VALID_PYVER
do
    build_1_in_place_and_test $p || continue
done

