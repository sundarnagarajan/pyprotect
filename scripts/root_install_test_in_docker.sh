#!/bin/bash
set -eu -o pipefail
PROG_DIR=$(readlink -f $(dirname $0))
SCRIPT_NAME=$(basename $0)
source "$PROG_DIR"/common_functions.sh

function run_tests() {
    # $1: TEST_DIR location
    [[ $# -lt 1 ]] && {
        >&2 red "Usage: run_tests <test_dir>"
        return 1
    }
    local local_test_dir=$1
    # optimistic that tests do not get overwritten / changed
    [[ -x "$local_test_dir"/$TEST_MODULE_FILENAME ]] || {
        mkdir -p "$local_test_dir"
        cp -a "${RELOCATED_DIR}"/$TESTS_DIR/. "$local_test_dir"/
    }
    cd /
    __TESTS_DIR=$local_test_dir "$PROG_DIR"/run_func_tests.sh $pyver
}

function install_test_1_pyver() {
    # $1: PYVER
    [[ $# -lt 1 ]] && {
        >&2 red "Usage: install_test_1_pyver <pyver>"
        return 1
    }
    local pyver=$1
    local PYTHON_BASENAME=${TAG_PYVER[$pyver]}
    local PYTHON_CMD=$(command_must_exist ${PYTHON_BASENAME}) || {
        >&2 red "${SCRIPT_NAME}: $pyver : python command not found: $PYTHON_BASENAME"
        return 1
    }
    [[ -z "$PYTHON_CMD" ]] && {
        >&2 red "${SCRIPT_NAME}: $pyver : python command not found: $PYTHON_BASENAME"
        return 1
    }
    local pip_cmd="${PYTHON_CMD} -m pip"
    local TEST_DIR=/root/tests

    run_1_cmd_in_relocated_dir "$PYTHON_CMD" -m pip uninstall -y $PY_MODULE

    run_1_cmd_in_relocated_dir $pip_cmd install .
    run_tests "$TEST_DIR"
    run_1_cmd_in_relocated_dir "$PYTHON_CMD" -m pip uninstall -y $PY_MODULE

    run_1_cmd_in_relocated_dir $PYTHON_CMD setup.py install
    run_tests "$TEST_DIR"
    run_1_cmd_in_relocated_dir "$PYTHON_CMD" -m pip uninstall -y $PY_MODULE

    [[ -n "${GIT_URL:-}" ]] || return 0

    run_1_cmd_in_relocated_dir $pip_cmd install git+${GIT_URL}
    run_tests "$TEST_DIR"
    run_1_cmd_in_relocated_dir "$PYTHON_CMD" -m pip uninstall -y $PY_MODULE
}


# ------------------------------------------------------------------------
# Actual script starts after this
# ------------------------------------------------------------------------

[[ $(id -u) -ne 0 ]] && {
    >&2 red "${SCRIPT_NAME}: Run as root"
    exit 1
}
echo "${SCRIPT_NAME}: Running in $(distro_name) as $(id -un)"
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

# This script launches a container only for cythonize_inplace.sh (above)
PYVER_CHOSEN=$@
VALID_PYVER=$(process_std_cmdline_args no yes $@)

${CLEAN_BUILD_SCRIPT}

for p in $VALID_PYVER
do
    ${CLEAN_BUILD_SCRIPT}
    chown -R $NORMAL_USER "${RELOCATED_DIR}"

    # Keep tests for each pyver together
    [[ -z ${NORMAL_USER+x} ]] && {
        >&2 red "NORMAL_USER env var not found"
    } || {
        su $NORMAL_USER -c "__RELOCATED_DIR="${RELOCATED_DIR}" ${PROG_DIR}/venv_test_install_inplace_in_docker.sh $p" || {
            [[ -n "$PYVER_CHOSEN" ]] && exit 1 || {
                ${CLEAN_BUILD_SCRIPT}
                continue
            }
        }
        ${CLEAN_BUILD_SCRIPT}
    }

    # Skip if __MINIMAL_TESTS is set
    [[ -z "${__MINIMAL_TESTS:-}" ]] && {
        echo "-------------------- Executing as root for $p --------------------"
        install_test_1_pyver $p || {
            [[ -n "$PYVER_CHOSEN" ]] && exit 1 || {
                ${CLEAN_BUILD_SCRIPT}
                continue
            }
        }
    }

done
${CLEAN_BUILD_SCRIPT}

