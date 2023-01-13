#!/bin/bash
# Fully reusable - changing only config.sh
#
set -eu -o pipefail
PROG_DIR=$(readlink -e $(dirname $0))
SCRIPT_NAME=$(basename $0)
source "$PROG_DIR"/common_functions.sh

function __run_tests() {
    # $1: PYVER - guaranteed to be in TAG_PYVER and have valid image in TAG_IMAGE
    [[ $# -lt 1 ]] && {
        >&2 red "Usage: run_1_in_venv PYTHON_VERSION_TAG"
        return 1
    }
    local pyver=$1
    local TEST_DIR=/tmp/tests
    # optimistic that we do not overwrite tests
    [[ -x "$TEST_DIR"/test_pyprotect.py ]] || {
        mkdir -p "$TEST_DIR"
        cp -a ${DOCKER_MOUNTPOINT}/tests/. "$TEST_DIR"/
    }
    cd /
    "$PROG_DIR"/run_func_tests.sh $pyver
}

function run_1_in_venv() {
    # $1: PYVER - guaranteed to be in TAG_PYVER and have valid image in TAG_IMAGE
    [[ $# -lt 1 ]] && {
        >&2 red "Usage: run_1_in_venv PYTHON_VERSION_TAG"
        return 1
    }
    local pyver=$1
    PYTHON_BASENAME=${TAG_PYVER[$pyver]}
    PYTHON_CMD=$(command_must_exist ${PYTHON_BASENAME}) || {
        >&2 red "$pyver : python command not found: $PYTHON_BASENAME"
        return 1
    }

    echo "---------- venv: Install and test with $pyver -----------------"
    local TEST_VENV_DIR=/tmp/test_venv
    echo "Clearing virtualenv dir"
    rm -rf ${TEST_VENV_DIR}
    echo "Creating virtualenv $PYTHON_CMD"
    hide_output_unless_error virtualenv -p $PYTHON_CMD ${TEST_VENV_DIR}
    source ${TEST_VENV_DIR}/bin/activate

    cd ${DOCKER_MOUNTPOINT}
    ${DOCKER_MOUNTPOINT}/scripts/clean_build.sh
    echo "Installing $PY_MODULE using $PYTHON_CMD -m pip"
    hide_output_unless_error $PYTHON_CMD -m pip install .
    ${DOCKER_MOUNTPOINT}/scripts/clean_build.sh

    echo "Running tests"
    __run_tests $pyver
    echo "Uninstalling $PY_MODULE using $PYTHON_CMD -m pip"
    hide_output_unless_error $PYTHON_CMD -m pip uninstall -y $PY_MODULE

    cd ${DOCKER_MOUNTPOINT}
    ${DOCKER_MOUNTPOINT}/scripts/clean_build.sh
    echo "Installing $PY_MODULE using $PYTHON_CMD setup.py"
    hide_output_unless_error $PYTHON_CMD setup.py install
    ${DOCKER_MOUNTPOINT}/scripts/clean_build.sh

    echo "Running tests"
    __run_tests $pyver

    echo "Uninstalling $PY_MODULE using $PYTHON_CMD -m pip"
    hide_output_unless_error $PYTHON_CMD -m pip uninstall -y $PY_MODULE
    rm -rf ${TEST_VENV_DIR}
}

function inplace_build_ant_test_1_pyver() {
    # $1: PYVER - guaranteed to be in TAG_PYVER and have valid image in TAG_IMAGE
    [[ $# -lt 1 ]] && {
        >&2 red "Usage: run_1_in_venv PYTHON_VERSION_TAG"
        return 1
    }
    local pyver=$1
    PYTHON_BASENAME=${TAG_PYVER[$pyver]}
    PYTHON_CMD=$(command_must_exist ${PYTHON_BASENAME}) || {
        >&2 red "$pyver : python command not found: $PYTHON_BASENAME"
        return 1
    }

    echo "---------- Inplace build and test with $pyver -----------------"
    cd ${DOCKER_MOUNTPOINT}
    ${DOCKER_MOUNTPOINT}/scripts/clean_build.sh
    ./scripts/cythonize.sh
    ./scripts/inplace_build.sh $pyver
    ${DOCKER_MOUNTPOINT}/scripts/clean_build.sh

    ${PROG_DIR}/run_func_tests.sh $pyver
}

# ------------------------------------------------------------------------
# Actual script starts after this
# ------------------------------------------------------------------------

echo "Running as $(id -un)"

must_be_in_docker

# Disable pip warnings that are irrelevant here
export PIP_DISABLE_PIP_VERSION_CHECK=1
export PIP_NO_PYTHON_VERSION_WARNING=1
export PIP_ROOT_USER_ACTION=ignore


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
    inplace_build_ant_test_1_pyver $p
    run_1_in_venv $p
done
