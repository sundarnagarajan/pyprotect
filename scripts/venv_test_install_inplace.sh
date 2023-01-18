#!/bin/bash
#
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
    echo "Running tests"
    rm -f "$RELOCATED_DIR"/$PY_MODULE/*.so
    cd /
    "$RELOCATED_DIR"/scripts/run_func_tests.sh $pyver
}

function create_activate_venv() {
    # $1: PYVER
    # $2: VENV_DIR
    [[ $# -lt 2 ]] && {
        >&2 red "Usage: run_1_in_venv PYTHON_VERSION_TAG VENV_DIR"
        return 1
    }
    local pyver=$1
    local VENV_DIR=$2
    local PYTHON_BASENAME=${TAG_PYVER[$pyver]}

    echo "---------- venv: Install and test with $pyver as $(id -un) -----------------"
    echo "Clearing virtualenv dir"
    rm -rf ${VENV_DIR}
    local PYTHON_CMD=$(command_must_exist ${PYTHON_BASENAME}) || {
        >&2 red "$pyver : python command not found: $PYTHON_BASENAME"
        return 1
    }
    echo "Creating virtualenv $PYTHON_CMD"
    $PYTHON_CMD -B -c 'import venv' 2>/dev/null && {
        hide_output_unless_error $PYTHON_CMD -m venv ${VENV_DIR} || return 1
    } || {
        hide_output_unless_error virtualenv -p $PYTHON_CMD ${VENV_DIR} || return 1
    }
    source ${VENV_DIR}/bin/activate
    command_must_exist ${PYTHON_BASENAME} 1>/dev/null || {
        >&2 red "$pyver : python command not found: $PYTHON_BASENAME"
        return 1
    }
}

function uninstall_in_venv() {
    # $1: PYTHON_CMD
    local py_cmd=$1
    echo "Uninstalling $PY_MODULE in virtualenv using $py_cmd -m pip"
    hide_output_unless_error $py_cmd -m pip uninstall -y $PY_MODULE || {
        deactivate
        return 1
    }
}

function exec_cmd_in_venv() {
    # $1: str to echo
    # $2+ : command to execute
    [[ $# -lt 2 ]] && {
        >&2 red "Usage: exec_cmd_in_venv <msg_str> <cmd> [args...]"
        return 1
    }
    local msg=$1
    shift

    cd ${RELOCATED_DIR}
    ${CLEAN_BUILD_SCRIPT}
    echo "$msg"
    hide_output_unless_error $@ || {
        deactivate
        return 1
    }
    ${CLEAN_BUILD_SCRIPT}
}

function run_1_in_venv() {
    # $1: PYVER
    [[ $# -lt 1 ]] && {
        >&2 red "Usage: run_1_in_venv PYTHON_VERSION_TAG"
        return 1
    }
    local pyver=$1
    local TEST_VENV_DIR=/tmp/test_venv

    create_activate_venv $pyver "$TEST_VENV_DIR" || return 1
    local PYTHON_BASENAME=${TAG_PYVER[$pyver]}
    local PYTHON_CMD=$(command_must_exist ${PYTHON_BASENAME}) || {
        >&2 red "$pyver : python command not found: $PYTHON_BASENAME"
        return 1
    }

    exec_cmd_in_venv "Installing $PY_MODULE in virtualenv using $PYTHON_CMD setup.py" $PYTHON_CMD setup.py install 
    __run_tests $pyver
    uninstall_in_venv "$PYTHON_CMD"

    exec_cmd_in_venv "Installing $PY_MODULE in virtualenv using $PYTHON_CMD -m pip install ." $PYTHON_CMD -m pip install . 
    __run_tests $pyver
    uninstall_in_venv "$PYTHON_CMD"

    [[ -n "${GIT_URL:-}" ]] || return 0

    exec_cmd_in_venv "Installing $PY_MODULE in virtualenv using $PYTHON_CMD -m pip install git+GIT_URL" $PYTHON_CMD -m pip install git+${GIT_URL}
    __run_tests $pyver
    uninstall_in_venv "$PYTHON_CMD"

    deactivate
    rm -rf ${TEST_VENV_DIR}
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
    cd ${RELOCATED_DIR}
    ${CLEAN_BUILD_SCRIPT}
    ${CYTHONIZE_SCRIPT}
    ${INPLACE_BUILD_SCRIPT} $pyver
    ${CLEAN_BUILD_SCRIPT}
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
    cd ${RELOCATED_DIR}
    ${CLEAN_BUILD_SCRIPT}
    echo "Installing $PY_MODULE using $PYTHON_CMD -m pip install --user ."
    hide_output_unless_error $PYTHON_CMD -m pip install --user . || {
        return 1
    }
    ${CLEAN_BUILD_SCRIPT}

    __run_tests $pyver
    echo "Uninstalling $PY_MODULE using $PYTHON_CMD -m pip"
    hide_output_unless_error $PYTHON_CMD -m pip uninstall -y $PY_MODULE || {
        return 1
    }
}


# ------------------------------------------------------------------------
# Actual script starts after this
# ------------------------------------------------------------------------

echo "${SCRIPT_NAME}: Running as $(id -un)"
echo "${SCRIPT_NAME}: Running in $(distro_name)"
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
INPLACE_BUILD_SCRIPT="${PROG_DIR}"/inplace_build.sh

# cythonize.sh already run in the correct image in host_install_test_in_docker.sh
[[ -f "${RELOCATED_DIR}"/${PY_MODULE}/${EXTENSION_NAME}.c ]] || {
    >&2 red "${RELOCATED_DIR}/${PY_MODULE}/${EXTENSION_NAME}.c not found"
    >&2 red "Should have already run cythonize.sh"
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
