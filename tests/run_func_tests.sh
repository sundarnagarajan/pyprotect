#!/bin/bash
# $1: PY3 | PY2 | PYPY3 | PYPY2 - defaults to testing in all

PROG_DIR=$(readlink -e $(dirname $0))
# We need $pwd in case we run it from Makefile dir (from Makefile)
# export PYTHONPATH="$(readlink -e "${PROG_DIR}"):$(pwd):$PYTHONPATH"
export PYTHONPATH=$(readlink -e "${PROG_DIR}")
TEST_SCRIPT="${PROG_DIR}/test_pyprotect.py"
set -eu -o pipefail

function red() {
    ANSI_ESC=$(printf '\033')
    ANSI_RS="${ANSI_ESC}[0m"    # reset
    ANSI_HC="${ANSI_ESC}[1m"    # hicolor
    ANSI_FRED="${ANSI_ESC}[31m" # foreground red

    echo -e "${ANSI_RS}${ANSI_HC}${ANSI_FRED}$@${ANSI_RS}"
}

function test_in_1_python() {
    # $1: python command to use
    local PYTHON=$1
    local ret=0
    $PYTHON -B -c "from pyprotect_finder import pyprotect" 1>/dev/null 2>&1 || ret=1
    if [[ $ret -eq 0 ]]; then
        echo "---------- Testing with $PYTHON ----------"
        $PYTHON -B "${TEST_SCRIPT}"
    else
        >&2 red "$PYVER $PYTHON module pyprotect not found"
        return 1
    fi
}

function run_all()
{
    if [[ "$IN_VENV" = "no" ]]; then
        local ret=0
        if [[ -z "$PYVER" || "$PYVER" = "PY3" ]]; then
            ret=0
            test_in_1_python python3
        fi
        if [[ -z "$PYVER" || "$PYVER" = "PY2" ]]; then
            ret=0
            test_in_1_python python2
        fi
        if [[ -z "$PYVER" || "$PYVER" = "PYPY3" ]]; then
        # if [[ "$PYVER" = "PYPY3" ]]; then
            ret=0
            test_in_1_python pypy3
        fi
        if [[ -z "$PYVER" || "$PYVER" = "PYPY2" ]]; then
        # if [[ "$PYVER" = "PYPY3" ]]; then
            ret=0
            test_in_1_python pypy
        fi
    else
        [[ -z "$PYVER" ]] && {
            test_in_1_python python
        } || {
            case "$PYVER" in
                PY3)
                    test_in_1_python python3
                    ;;
                PY2)
                    test_in_1_python python2
                    ;;
                PYPY3)
                    test_in_1_python pypy3
                    ;;
                PYPY2)
                    test_in_1_python pypy
                    ;;
                *)
                    >&2 red "Unknown PYVER: $PYVER"
                    return 1
                    ;;
            esac
        }
    fi
}

env | grep -q '^VIRTUAL_ENV' && IN_VENV=yes || IN_VENV=no
if [[ "$IN_VENV" = "yes" ]]; then
    echo "Running in virtualenv"
fi
[[ $# -lt 1 ]] && PYVER="" || {
    [[ "$1" = "PY2" || "$1" = "PY3" || "$1" = "PYPY3" || "$1" = "PYPY2" ]] || {
        >&2 red "Unknown PYVER: $1"
        exit 1
    }
    PYVER=$1
    shift
}

cd "${PROG_DIR}"

run_all
