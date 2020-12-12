#!/bin/bash
# $1: either PY2 or PY3 - defaults to testing in both

PROG_DIR=$(readlink -e $(dirname $0))
export PYTHONPATH="$(readlink -e "${PROG_DIR}"/..):$PYTHONPATH"
TEST_SCRIPT="${PROG_DIR}/test_protected_class.py"
TEST_CASE_FILE="${PROG_DIR}/testcases.txt"
MODULE_NAME=protected_class


if [[ "$1" = "PY2" || "$1" = "PY3" ]]; then
    PYVER=$1
    shift
else
    PYVER=""
fi

if [[ -f "$TEST_CASE_FILE" ]]; then
    if [[ -z "$PYVER" || "$PYVER" = "PY3" ]]; then
        ret=0
        python3 -c "import $MODULE_NAME" 1>/dev/null 2>&1 || ret=1
        if [[ $ret -eq 0 ]]; then
            echo "---------- Testing in Python3 ----------"
            python3 "$TEST_SCRIPT" $@
        else
            >&2 echo "Python 3 module $MODULE_NAME not found"
            if [[ -n "$PYVER" ]]; then
                exit 1
            fi
        fi
    fi
    if [[ -z "$PYVER" || "$PYVER" = "PY2" ]]; then
        ret=0
        python2 -c "import $MODULE_NAME" 1>/dev/null 2>&1 || ret=1
        if [[ $ret -eq 0 ]]; then
            echo "---------- Testing in Python2 ----------"
            python2 "$TEST_SCRIPT" $@
        else
            >&2 echo "Python 2 module $MODULE_NAME not found"
            if [[ -n "$PYVER" ]]; then
                exit 1
            fi
        fi
    fi
else
    >&2 echo "Test cases not found: $TEST_CASE_FILE"
fi
