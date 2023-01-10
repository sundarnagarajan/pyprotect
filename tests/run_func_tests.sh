#!/bin/bash
# $1: either PY2 or PY3 - defaults to testing in both

PROG_DIR=$(readlink -e $(dirname $0))
# We need $pwd in case we run it from Makefile dir (from Makefile)
# export PYTHONPATH="$(readlink -e "${PROG_DIR}"):$(pwd):$PYTHONPATH"
export PYTHONPATH=$(readlink -e "${PROG_DIR}")
TEST_SCRIPT="${PROG_DIR}/test_pyprotect.py"

env | grep -q '^VIRTUAL_ENV' && IN_VENV=yes || IN_VENV=no
if [[ "$IN_VENV" = "yes" ]]; then
    echo "Running in virtualenv"
fi
if [[ "$1" = "PY2" || "$1" = "PY3" || "$1" = "PYPY3" || "$1" = "PYPY" ]]; then
    PYVER=$1
    shift
else
    PYVER=""
fi
REST_ARGS=$@

cd "${PROG_DIR}"

function test_in_1_python() {
    # $1: python command to use
    local PYTHON=$1
    local ret=0
    $PYTHON -B -c "from pyprotect_finder import pyprotect" 1>/dev/null 2>&1 || ret=1
    if [[ $ret -eq 0 ]]; then
        echo "---------- Testing in $PYTHON ----------"
        $PYTHON -B "${TEST_SCRIPT}" $REST_ARGS
    else
        >&2 echo "$PYTHON module $MODULE_NAME not found"
        return 1
    fi
}

function run_all()
{
    if [[ "$IN_VENV" = "no" ]]; then
        local ret=0
        if [[ -z "$PYVER" || "$PYVER" = "PY3" ]]; then
            ret=0
            test_in_1_python python3 || ret=1
            if [[ $ret -ne 0 && -n "$PYVER" ]]; then
                exit 1
            fi
        fi
        if [[ -z "$PYVER" || "$PYVER" = "PY2" ]]; then
            ret=0
            test_in_1_python python2 || ret=1
            if [[ $ret -ne 0 && -n "$PYVER" ]]; then
                exit 1
            fi
        fi
        # For some reason test_01_multiwrap_1300_tests is VERY slow on PPY3
        # So PYPY3 is run only if explicitly requested
        if [[ -z "$PYVER" || "$PYVER" = "PYPY3" ]]; then
        # if [[ "$PYVER" = "PYPY3" ]]; then
            ret=0
            test_in_1_python pypy3 || ret=1
            if [[ $ret -ne 0 && -n "$PYVER" ]]; then
                exit 1
            fi
        fi
    else
        test_in_1_python python
    fi
}

run_all
