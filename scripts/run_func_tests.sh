#!/bin/bash
# $1: PY3 | PY2 | PYPY3 | PYPY2 - defaults to testing in all

set -eu -o pipefail
PROG_DIR=$(readlink -f $(dirname $0))
SCRIPT_NAME=$(basename $0)
source "$PROG_DIR"/common_functions.sh
TEST_SCRIPT_BASENAME=$TEST_MODULE_FILENAME

function test_in_1_pyver() {
    # $1: PYVER - guaranteed to be in TAG_PYVER and have valid image in TAG_IMAGE
    local pyver=$1
    local python_cmd_basename=${TAG_PYVER[${pyver}]}
    python_cmd=$(command_must_exist $python_cmd_basename) || {
        >&2 red "$pyver : Command not found: $python_cmd_basename"
        return 1
    }

    local ret=0
    $python_cmd -B -c "from module_finder import ${PY_MODULE}" 1>/dev/null 2>&1 || ret=1
    
    if [[ $ret -eq 0 ]]; then
        echo "Executing tests in: $__TESTS_DIR"
        echo "$pyver : Testing with $python_cmd"
        $python_cmd -B "${TEST_SCRIPT_BASENAME}"
    else
        >&2 red "$pyver : $python_cmd module ${PY_MODULE} not found"
        return 1
    fi
}

# ------------------------------------------------------------------------
# Actual script starts after this
# ------------------------------------------------------------------------

# If __TESTS_DIR env var is set, ONLY $TESTS_DIR/$TEST_MODULE_FILENAME is tried
# Otherwise ONLY $PROG_DIR/../tests/$TEST_MODULE_FILENAME is tried

[[ -n $(declare -p __TESTS_DIR 2>/dev/null) ]] && {
    TEST_SCRIPT=$(readlink -f "$__TESTS_DIR")/$TEST_MODULE_FILENAME
} || {
    __TESTS_DIR=$(readlink -f "$PROG_DIR"/../tests)
}
# export PYTHONPATH=$__TESTS_DIR

PYVER_CHOSEN=$@
# This script does not launch docker containers
VALID_PYVER=$(process_std_cmdline_args no yes $@)

env | grep -q '^VIRTUAL_ENV' && IN_VENV=yes || IN_VENV=no
if [[ "$IN_VENV" = "yes" ]]; then
    echo "${SCRIPT_NAME}: Running in virtualenv"
fi

for p in $VALID_PYVER
do
    cd "${__TESTS_DIR}"
    test_in_1_pyver $p || {
        [[ -n "$PYVER_CHOSEN" ]] && exit 1 || continue
    }
done
