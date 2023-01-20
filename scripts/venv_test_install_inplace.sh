#!/bin/bash
set -eu -o pipefail
PROG_DIR=$(readlink -f $(dirname $0))
SCRIPT_NAME=$(basename $0)
source "$PROG_DIR"/common_functions.sh

function run_1_cmd_in_relocated_dir() {
    # $@ : command to execute
    # Needs following vars set:
    #   RELOCATED_DIR
    #   CLEAN_BUILD_SCRIPT
    [[ $# -lt 1 ]] && {
        >&2 red "Usage: run_1_cmd_in_relocated_dir <cmd> [args...]"
        return 1
    }
    var_empty RELOCATED_DIR && {
        >&2 red "${SCRIPT_NAME:-}: run_1_cmd_in_relocated_dir: Needs RELOCATED_DIR set"
        return 1
    }
    var_empty CLEAN_BUILD_SCRIPT && {
        >&2 red "run_1_cmd_in_relocated_dir: Needs CLEAN_BUILD_SCRIPT set"
        return 1
    }
    cd ${RELOCATED_DIR}
    ${CLEAN_BUILD_SCRIPT}
    echo -e "${SCRIPT_NAME:-}: ($(id -un)): $@"
    hide_output_unless_error $@ || return 1
    ${CLEAN_BUILD_SCRIPT}
}

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

    echo "${SCRIPT_NAME}: Clearing virtualenv dir"
    rm -rf ${VENV_DIR}
    local PYTHON_CMD=$(command_must_exist ${PYTHON_BASENAME}) || {
        >&2 red "$pyver : python command not found: $PYTHON_BASENAME"
        return 1
    }
    echo "${SCRIPT_NAME}: Creating virtualenv $PYTHON_CMD"
    $PYTHON_CMD -B -c 'import venv' 2>/dev/null && {
        hide_output_unless_error $PYTHON_CMD -m venv ${VENV_DIR} || return 1
    } || {
        hide_output_unless_error virtualenv -p $PYTHON_CMD ${VENV_DIR} || return 1
    }
    source ${VENV_DIR}/bin/activate
    command_must_exist ${PYTHON_BASENAME} 1>/dev/null || {
        >&2 red "${SCRIPT_NAME}: $pyver : python command not found: $PYTHON_BASENAME"
        return 1
    }
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
