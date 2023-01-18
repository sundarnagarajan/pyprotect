#!/bin/bash
#
set -eu -o pipefail
PROG_DIR=$(readlink -f $(dirname $0))
SCRIPT_NAME=$(basename $0)
source "$PROG_DIR"/common_functions.sh

function install_test_1_pyver() {
    # $1: PYVER - guaranteed to be in TAG_PYVER and have valid image in TAG_IMAGE
    local pyver=$1
    local PYTHON_BASENAME=${TAG_PYVER[$pyver]}
    local PYTHON_CMD=$(command_must_exist ${PYTHON_BASENAME}) || {
        >&2 red "$pyver : python command not found: $PYTHON_BASENAME"
        return 1
    }
    [[ -z "$PYTHON_CMD" ]] && {
        >&2 red "$pyver : python command not found: $PYTHON_BASENAME"
        return 1
    }
    local pip_cmd="${PYTHON_CMD} -m pip"

    cd ${DOCKER_MOUNTPOINT}
    echo "Uninstalling using $pip_cmd uninstall"
    hide_output_unless_error $pip_cmd uninstall -y $PY_MODULE || return 1

    cd ${DOCKER_MOUNTPOINT}
    ${CLEAN_BUILD_SCRIPT}
    echo "Installing ${PY_MODULE} using $pip_cmd install ."
    unset PYTHONDONTWRITEBYTECODE
    hide_output_unless_error $pip_cmd install . || return 1
    export PYTHONDONTWRITEBYTECODE=Y
    ${CLEAN_BUILD_SCRIPT}

    local TEST_DIR=/root/tests
    # optimistic that tests do not get overwritten / changed
    [[ -x "$TEST_DIR"/$TEST_MODULE_FILENAME ]] || {
        mkdir -p "$TEST_DIR"
        cp -a "${DOCKER_MOUNTPOINT}"/tests/. "$TEST_DIR"/
    }
    cd /
    __TESTS_DIR=$TEST_DIR "$PROG_DIR"/run_func_tests.sh $pyver

    cd ${DOCKER_MOUNTPOINT}
    echo "Uninstalling using $pip_cmd uninstall"
    hide_output_unless_error $pip_cmd uninstall -y $PY_MODULE || return 1

    cd ${DOCKER_MOUNTPOINT}
    ${CLEAN_BUILD_SCRIPT}
    echo "Installing ${PY_MODULE} using $PYTHON_CMD setup.py install"
    unset PYTHONDONTWRITEBYTECODE
    hide_output_unless_error $PYTHON_CMD setup.py install || return 1
    export PYTHONDONTWRITEBYTECODE=Y
    ${CLEAN_BUILD_SCRIPT}

    local TEST_DIR=/root/tests
    # optimistic that tests do not get overwritten / changed
    [[ -x "$TEST_DIR"/$TEST_MODULE_FILENAME ]] || {
        mkdir -p "$TEST_DIR"
        cp -a "${DOCKER_MOUNTPOINT}"/tests/. "$TEST_DIR"/
    }
    cd /
    __TESTS_DIR=$TEST_DIR "$PROG_DIR"/run_func_tests.sh $pyver

    cd ${DOCKER_MOUNTPOINT}
    echo "Uninstalling using $pip_cmd uninstall"
    hide_output_unless_error $pip_cmd uninstall -y $PY_MODULE || return 1

    [[ -n "${GIT_URL:-}" ]] || return 0

    cd ${DOCKER_MOUNTPOINT}
    ${CLEAN_BUILD_SCRIPT}
    echo "Installing ${PY_MODULE} using $pip_cmd install git+GIT_URL"
    unset PYTHONDONTWRITEBYTECODE
    hide_output_unless_error $pip_cmd install git+${GIT_URL} || return 1
    export PYTHONDONTWRITEBYTECODE=Y
    ${CLEAN_BUILD_SCRIPT}

    local TEST_DIR=/root/tests
    # optimistic that tests do not get overwritten / changed
    [[ -x "$TEST_DIR"/$TEST_MODULE_FILENAME ]] || {
        mkdir -p "$TEST_DIR"
        cp -a "${DOCKER_MOUNTPOINT}"/tests/. "$TEST_DIR"/
    }
    cd /
    __TESTS_DIR=$TEST_DIR "$PROG_DIR"/run_func_tests.sh $pyver

    cd ${DOCKER_MOUNTPOINT}
    echo "Uninstalling using $pip_cmd uninstall"
    hide_output_unless_error $pip_cmd uninstall -y $PY_MODULE || return 1
}

# ------------------------------------------------------------------------
# Actual script starts after this
# ------------------------------------------------------------------------

[[ $(id -u) -ne 0 ]] && {
    >&2 red "${SCRIPT_NAME}: Run as root"
    exit 1
}
echo "${SCRIPT_NAME}: Running in $(distro_name)"
must_be_in_docker

# Disable pip warnings that are irrelevant here
export PIP_DISABLE_PIP_VERSION_CHECK=1
export PIP_NO_PYTHON_VERSION_WARNING=1
export PIP_ROOT_USER_ACTION=ignore

CLEAN_BUILD_SCRIPT="${PROG_DIR}"/clean_build.sh
CYTHONIZE_SCRIPT="${PROG_DIR}"/cythonize.sh

# This script does not launch docker containers
PYVER_CHOSEN=$@
VALID_PYVER=$(process_std_cmdline_args no yes $@)

cd ${DOCKER_MOUNTPOINT}
${CYTHONIZE_SCRIPT}
${CLEAN_BUILD_SCRIPT}

for p in $VALID_PYVER
do
    # Skip if __MINIMAL_TESTS is set
    [[ -z "${__MINIMAL_TESTS:-}" ]] && {
        echo "-------------------- Executing for $p --------------------"
        install_test_1_pyver $p || {
            [[ -n "$PYVER_CHOSEN" ]] && exit 1 || {
                ${CLEAN_BUILD_SCRIPT}
                continue
            }
        }
        ${CLEAN_BUILD_SCRIPT}
    }

    # Keep tests for each pyver together
    [[ -z ${NORMAL_USER+x} ]] && {
        >&2 red "NORMAL_USER env var not found"
    } || {
        su $NORMAL_USER -c "__CONFIG_DOCKER=${__CONFIG_DOCKER:-}  ${PROG_DIR}/venv_test_install_inplace.sh $p" || {
            [[ -n "$PYVER_CHOSEN" ]] && exit 1 || {
                ${CLEAN_BUILD_SCRIPT}
                continue
            }
        }
    }
done
${CLEAN_BUILD_SCRIPT}

