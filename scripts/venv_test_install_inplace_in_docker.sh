#!/bin/bash
set -eu -o pipefail
PROG_DIR=$(readlink -f $(dirname $0))
SCRIPT_NAME=$(basename $0)
source "$PROG_DIR"/common_functions.sh

function __run_tests() {
    # $1: PYVER
    # Do not need to copy tests; can just use $RELOCATED_DIR
    [[ $# -lt 1 ]] && {
        >&2 red "Usage: run_1_in_venv PYTHON_VERSION_TAG"
        return 1
    }
    local pyver=$1
    cd /
    "$RELOCATED_DIR"/scripts/run_func_tests.sh $pyver
}

function run_1_in_venv() {
    # $1: PYVER
    [[ $# -lt 1 ]] && {
        >&2 red "Usage: run_1_in_venv PYTHON_VERSION_TAG"
        return 1
    }
    local pyver=$1
    local TEST_VENV_DIR=/tmp/test_venv
    echo "---------- venv: Install and test with $pyver as $(id -un) -----------------"

    function cleanup_venv() {
        deactivate
        rm -rf "$TEST_VENV_DIR"
    }

    create_activate_venv $pyver "$TEST_VENV_DIR" || return 1
    trap cleanup_venv RETURN

    local PYTHON_BASENAME=${TAG_PYVER[$pyver]}
    local PYTHON_CMD=$(command_must_exist ${PYTHON_BASENAME}) || {
        >&2 red "${SCRIPT_NAME}: $pyver : python command not found: $PYTHON_BASENAME"
        return 1
    }

    run_1_cmd_in_relocated_dir $PYTHON_CMD setup.py install || return 1
    __run_tests $pyver|| return 1
    run_1_cmd_in_relocated_dir "$PYTHON_CMD" -m pip uninstall -y $PY_MODULE|| return 1

    run_1_cmd_in_relocated_dir $PYTHON_CMD -m pip install . || return 1
    __run_tests $pyver|| return 1
    run_1_cmd_in_relocated_dir "$PYTHON_CMD" -m pip uninstall -y $PY_MODULE|| return 1

    [[ -n "${GIT_URL:-}" ]] || return 0

    run_1_cmd_in_relocated_dir $PYTHON_CMD -m pip install git+${GIT_URL}|| return 1
    __run_tests $pyver|| return 1
    run_1_cmd_in_relocated_dir "$PYTHON_CMD" -m pip uninstall -y $PY_MODULE|| return 1
}

function inplace_build_and_test_1_pyver() {
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
    run_1_cmd_in_relocated_dir ${INPLACE_BUILD_SCRIPT} $pyver || return 1
    __run_tests $pyver|| return 1
}

function pip_install_user_1_pyver() {
    # $1: PYVER - guaranteed to be in TAG_PYVER and have valid image in TAG_IMAGE
    [[ $# -lt 1 ]] && {
        >&2 red "Usage: pip_install_user_1_pyver PYTHON_VERSION_TAG"
        return 1
    }
    local pyver=$1
    PYTHON_BASENAME=${TAG_PYVER[$pyver]}
    PYTHON_CMD=$(command_must_exist ${PYTHON_BASENAME}) || {
        >&2 red "$pyver : python command not found: $PYTHON_BASENAME"
        return 1
    }

    echo "---------- Install and test --user with $pyver -----------------"
    run_1_cmd_in_relocated_dir $PYTHON_CMD -m pip install --user . || return 1
    __run_tests $pyver
    run_1_cmd_in_relocated_dir $PYTHON_CMD -m pip uninstall -y $PY_MODULE || return 1
}


# ------------------------------------------------------------------------
# Actual script starts after this
# ------------------------------------------------------------------------

echo "${SCRIPT_NAME}: Running in $(distro_name) as $(id -un)"
must_be_in_docker

PROG_DIR="$(relocate_source)"/scripts
PROG_DIR=$(readlink -f "$PROG_DIR")
RELOCATED_DIR=$(readlink -f "${PROG_DIR}"/..)
echo "${SCRIPT_NAME}: Running in $PROG_DIR"

# Disable pip warnings that are irrelevant here
export PIP_DISABLE_PIP_VERSION_CHECK=1
export PIP_NO_PYTHON_VERSION_WARNING=1
export PIP_ROOT_USER_ACTION=ignore

CLEAN_BUILD_SCRIPT="${PROG_DIR}"/clean_build.sh
INPLACE_BUILD_SCRIPT="${PROG_DIR}"/build_test_inplace.sh

# cythonize_inplace.sh already run in the correct image in host_install_test_in_docker.sh
[[ -f "${RELOCATED_DIR}"/${PY_MODULE}/${EXTENSION_NAME}.c ]] || {
    >&2 red "${RELOCATED_DIR}/${PY_MODULE}/${EXTENSION_NAME}.c not found"
    >&2 red "Should have already run cythonize_inplace.sh"
    exit 1
}

# This script does not launch docker containers
VALID_PYVER=$(process_std_cmdline_args no yes $@)

[[ -z "${__MINIMAL_TESTS:-}" ]] && {
    for p in $VALID_PYVER
    do
            run_1_in_venv $p
            ${CLEAN_BUILD_SCRIPT}
            pip_install_user_1_pyver $p
            ${CLEAN_BUILD_SCRIPT}
    done
}


for p in $VALID_PYVER
do
    inplace_build_and_test_1_pyver $p
    ${CLEAN_BUILD_SCRIPT}
    rm -f "${RELOCATED_DIR}"/${PY_MODULE}/*.so
done
