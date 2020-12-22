#!/bin/bash
# $1: either PY2 or PY3 - defaults to testing in both

PROG_DIR=$(readlink -e $(dirname $0))
# We need $pwd) in case we run it from Makefile dir (from Makefile)
export PYTHONPATH="$(readlink -e "${PROG_DIR}"):$(pwd):$PYTHONPATH"
TEST_SCRIPT="${PROG_DIR}/test_protected_class.py"
MODULE_NAME=protected_class

env | grep -q '^VIRTUAL_ENV' && IN_VENV=yes || IN_VENV=no
if [[ "$IN_VENV" = "yes" ]]; then
    echo "Running in virtualenv"
fi
if [[ "$1" = "PY2" || "$1" = "PY3" ]]; then
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
    $PYTHON -c "import $MODULE_NAME" 1>/dev/null 2>&1 || ret=1
    if [[ $ret -eq 0 ]]; then
        echo "---------- Testing in $PYTHON ----------"
        $PYTHON test_protected_class.py $REST_ARGS
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
    else
        test_in_1_python python
    fi
}

run_all
