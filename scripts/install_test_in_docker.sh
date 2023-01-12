#!/bin/bash
# Fully reusable - changing only config.sh
#
set -eu -o pipefail
PROG_DIR=$(readlink -e $(dirname $0))
SCRIPT_NAME=$(basename $0)
source "$PROG_DIR"/../scripts/config.sh
source "$PROG_DIR"/common_functions.sh

function uninstall() {
    cd ${DOCKER_MOUNTPOINT}
    for cmd in pip3 pip2 "pypy3 -m pip" "pypy -m pip"
    do
        echo "Uninstalling using $cmd uninstall"
        hide_output_unless_error $cmd uninstall -y $PY_MODULE
    done
}

function install_pip() {
    cd ${DOCKER_MOUNTPOINT}
    ${DOCKER_MOUNTPOINT}/scripts/clean_build.sh
    for cmd in pip3 pip2 "pypy3 -m pip" "pypy -m pip"
    do
        echo "Installing using $cmd install ."
        hide_output_unless_error $cmd install .
    done
    ${DOCKER_MOUNTPOINT}/scripts/clean_build.sh
}

function install_setup() {
    cd ${DOCKER_MOUNTPOINT}
    ${DOCKER_MOUNTPOINT}/scripts/clean_build.sh
    for cmd in python3 python2 pypy3 pypy
    do
        echo "Installing using $cmd setup.py install"
        hide_output_unless_error $cmd setup.py install
    done
    ${DOCKER_MOUNTPOINT}/scripts/clean_build.sh
}

function run_tests() {
    local TEST_DIR=/root/tests
    # optimistic that we do not overwrite tests
    [[ -x "$TEST_DIR"/run_func_tests.sh ]] || {
        mkdir -p "$TEST_DIR"
        cp -a "${DOCKER_MOUNTPOINT}"/tests/. "$TEST_DIR"/
    }
    cd /
    for p in PY3 PY2 PYPY3 PYPY2
    do
        "$TEST_DIR"/run_func_tests.sh $p
    done
}

# ------------------------------------------------------------------------
# Actual script starts after this
# ------------------------------------------------------------------------

[[ $(id -u) -ne 0 ]] && {
    >&2 red "${SCRIPT_NAME}: Run as root"
    exit 1
}
must_be_in_docker

# Disable pip warnings that are irrelevant here
export PIP_DISABLE_PIP_VERSION_CHECK=1
export PIP_NO_PYTHON_VERSION_WARNING=1
export PIP_ROOT_USER_ACTION=ignore

cd ${DOCKER_MOUNTPOINT}
${DOCKER_MOUNTPOINT}/scripts/cythonize.sh

uninstall
install_pip
run_tests
uninstall
install_setup
run_tests

[[ -z ${NORMAL_USER+x} ]] && {
    >&2 red "NORMAL_USER env var not found"
} || {
    su $NORMAL_USER -c "${PROG_DIR}"/venv_test_install_inplace.sh
}
