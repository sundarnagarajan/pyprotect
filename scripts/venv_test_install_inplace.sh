#!/bin/bash
# Fully reusable - changing only config.sh
#
set -eu -o pipefail
PROG_DIR=$(readlink -e $(dirname $0))
SCRIPT_NAME=$(basename $0)
source "$PROG_DIR"/../scripts/config.sh
source "$PROG_DIR"/common_functions.sh

function __run_tests() {
    # $1: one of PY3 | PY2 | PYPY3 | PYPY2
    # Only expected to be called from within this script
    local TEST_DIR=/tmp/tests
    # optimistic that we do not overwrite tests
    [[ -x "$TEST_DIR"/run_func_tests.sh ]] || {
        mkdir -p "$TEST_DIR"
        cp -a /home/tests/. "$TEST_DIR"/
    }
    cd /
    "$TEST_DIR"/run_func_tests.sh $1
}

function run_1_in_venv() {
    # $1: one of PY3 | PY2 | PYPY3 | PYPY2
    [[ $# -lt 1 ]] && {
        >&2 red "Usage: run_1_in_venv PY3 | PY2 | PYPY3 | PYPY2"
        return 1
    }
    local PY_CHOICE=$1
    local PY_CMD=""

    case "$PY_CHOICE" in 
        PY3)
            PY_CMD=python3
            ;;
        PY2)
            PY_CMD=python2
            ;;
        PYPY3)
            PY_CMD=pypy3
            ;;
        PYPY2)
            PY_CMD=pypy
            ;;
        *)
            red "Usage: run_1_in_venv PY3 | PY2 | PYPY3 | PYPY2"
            return 1
    esac

    echo "---------- venv: Install and test with $PY_CHOICE -----------------"
    local TEST_VENV_DIR=/tmp/test_venv
    echo "Clearing virtualenv dir"
    rm -rf ${TEST_VENV_DIR}
    echo "Creating virtualenv $PY_CMD"
    hide_output_unless_error virtualenv -p $PY_CMD ${TEST_VENV_DIR}
    source ${TEST_VENV_DIR}/bin/activate

    cd ${DOCKER_MOUNTPOINT}
    ${DOCKER_MOUNTPOINT}/scripts/clean_build.sh
    echo "Installing pyprotect using pip"
    hide_output_unless_error pip install .
    ${DOCKER_MOUNTPOINT}/scripts/clean_build.sh

    echo "Running tests"
    __run_tests $PY_CHOICE
    echo "Uninstalling pyprotect using pip"
    hide_output_unless_error pip uninstall -y pyprotect

    cd ${DOCKER_MOUNTPOINT}
    ${DOCKER_MOUNTPOINT}/scripts/clean_build.sh
    echo "Installing pyprotect using $PY_CMD setup.py"
    hide_output_unless_error $PY_CMD setup.py install
    ${DOCKER_MOUNTPOINT}/scripts/clean_build.sh

    echo "Running tests"
    __run_tests $PY_CHOICE
    echo "Uninstalling pyprotect using pip"
    hide_output_unless_error pip uninstall -y pyprotect
    rm -rf ${TEST_VENV_DIR}
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

for p in python3 python2 pypy3 pypy
do
    echo "---------- Inplace build and test with $p -----------------"
    cd ${DOCKER_MOUNTPOINT}
    ./scripts/cythonize.sh
    ./scripts/inplace_build.sh $p
    ${DOCKER_MOUNTPOINT}/scripts/clean_build.sh
    case "$p" in 
        python3)
            PY_CHOICE=PY3
            ;;
        python2)
            PY_CHOICE=PY2
            ;;
        pypy3)
            PY_CHOICE=PYPY3
            ;;
        pypy)
            PY_CHOICE=PYPY2
            ;;
    esac
    ./tests/run_func_tests.sh $PY_CHOICE
done
${DOCKER_MOUNTPOINT}/scripts/clean_build.sh

cd ${DOCKER_MOUNTPOINT}
${DOCKER_MOUNTPOINT}/scripts/cythonize.sh
for p in PY3 PY2 PYPY3 PYPY2
do
    run_1_in_venv $p || true
done

