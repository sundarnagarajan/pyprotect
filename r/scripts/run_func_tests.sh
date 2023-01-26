#!/bin/bash
# $1: PY3 | PY2 | PYPY3 | PYPY2 - defaults to testing in all

set -eu -o pipefail
PROG_DIR=$(readlink -f $(dirname $0))
SCRIPT_NAME=$(basename $0)
source "$PROG_DIR"/common_functions.sh

function test_in_1_pyver() {
    # $1: PYVER - guaranteed to be in TAG_PYVER and have valid image in TAG_IMAGE
    local pyver=$1
    local python_cmd_basename=${TAG_PYVER[${pyver}]}
    python_cmd=$(command_must_exist $python_cmd_basename) || {
        >&2 red "$(basename ${BASH_SOURCE})(${FUNCNAME[0]}): $pyver : Command not found: $python_cmd_basename"
        return 1
    }

    local ret=0
    cd "$__TESTS_DIR"

    $python_cmd -B -c "from module_finder import ${PY_MODULE}" 1>/dev/null 2>&1 || ret=1
    
    if [[ $ret -eq 0 ]]; then
        var_empty __NOTEST && {
            [[ $VERBOSITY -lt 3 ]] || echo "${SCRIPT_NAME}: $python_cmd ${__TESTS_DIR}/${TEST_MODULE_FILENAME}"
            [[ $VERBOSITY -lt 1 ]] && {
                hide_output_unless_error $python_cmd -B "${TEST_MODULE_FILENAME}" || return $?
            } || {
                # If we are showing (only) test outputs, also add a line showing what is being tested
                [[ $VERBOSITY -eq 1 ]] && echo "Testing for $python_cmd in $running_env"
                $python_cmd -B "${TEST_MODULE_FILENAME}" || return $?
            }
        } || {
            [[ $VERBOSITY -lt 4 ]] || >&2 blue "${SCRIPT_NAME}: __NOTEST set, not executing tests with $python_cmd ${__TESTS_DIR}/${TEST_MODULE_FILENAME}"
            return
        }
    else
        >&2 red "$(basename ${BASH_SOURCE})(${FUNCNAME[0]}): $pyver : $python_cmd module ${PY_MODULE} not found"
        return 1
    fi
}

# ------------------------------------------------------------------------
# Actual script starts after this
# ------------------------------------------------------------------------
env | grep -q '^VIRTUAL_ENV' && IN_VENV=yes || IN_VENV=no
[[ "$IN_VENV" = "yes" ]] && {
    running_env="$(distro_name) as $(id -un) in virtualenv"
} || {
    running_env="$(distro_name) as $(id -un)"
}
[[ $VERBOSITY -lt 2 ]] || echo "${SCRIPT_NAME}: Running in $running_env"

# If __TESTS_DIR env var is set, ONLY $TESTS_DIR/$TEST_MODULE_FILENAME is tried
# Otherwise ONLY $PROG_DIR/../$TESTS_DIR/$TEST_MODULE_FILENAME is tried

[[ -n $(declare -p __TESTS_DIR 2>/dev/null) ]] || {
    __TESTS_DIR=$(readlink -f "$SOURCE_TOPLEVEL_DIR"/$TESTS_DIR)
}

PYVER_CHOSEN=$@
# This script does not launch docker containers
VALID_PYVER=$(process_std_cmdline_args no yes $@)

for p in $VALID_PYVER
do
    cd "${__TESTS_DIR}"
    test_in_1_pyver $p || {
        [[ -n "$PYVER_CHOSEN" ]] && exit 1 || continue
    }
done
