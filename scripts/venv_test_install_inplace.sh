#!/bin/bash
#
set -eu -o pipefail
PROG_DIR=$(readlink -f $(dirname $0))
SCRIPT_NAME=$(basename $0)
source "$PROG_DIR"/common_functions.sh

function __run_tests() {
    # $1: PYVER - guaranteed to be in TAG_PYVER and have valid image in TAG_IMAGE
    [[ $# -lt 1 ]] && {
        >&2 red "Usage: run_1_in_venv PYTHON_VERSION_TAG"
        return 1
    }
    local pyver=$1
    local TEST_DIR=/tmp/tests
    # optimistic that tests will not be overwritten / changed
    [[ -x "$TEST_DIR"/$TEST_MODULE_FILENAME ]] || {
        # Check that TEST_DIR is writeable
        [[ -e "$TEST_DIR" && ! -d "$TEST_DIR" ]] && {
            ( rm -f "$TEST_DIR" && mkdir -p "$TEST_DIR" ) || {
                >&2 red "TEST_DIR: $TEST_DIR is a non-directory, but cannot be replaced"
                return 1
            }
        }
        [[ -d "$TEST_DIR" ]] || {
            mkdir -p "$TEST_DIR" || {
                >&2 red "Could not create TEST_DIR: $TEST_DIR"
                return 1
            }
        }
        [[ -w "$TEST_DIR" ]] || {
            >&2 red "TEST_DIR not writeable: $TEST_DIR"
            return 1
        }
        cp -a --no-clobber ${DOCKER_MOUNTPOINT}/tests/. "$TEST_DIR"/ || {
            >&2 red "Copying to TEST_DIR failed: $TEST_DIR"
            return 1
        }
    }
    cd /
    __TESTS_DIR="$TEST_DIR" "$PROG_DIR"/run_func_tests.sh $pyver
}

function run_1_in_venv() {
    # $1: PYVER - guaranteed to be in TAG_PYVER and have valid image in TAG_IMAGE
    [[ $# -lt 1 ]] && {
        >&2 red "Usage: run_1_in_venv PYTHON_VERSION_TAG"
        return 1
    }
    local pyver=$1
    PYTHON_BASENAME=${TAG_PYVER[$pyver]}

    echo "---------- venv: Install and test with $pyver -----------------"
    local TEST_VENV_DIR=/tmp/test_venv
    echo "Clearing virtualenv dir"
    rm -rf ${TEST_VENV_DIR}
    PYTHON_CMD=$(command_must_exist ${PYTHON_BASENAME}) || {
        >&2 red "$pyver : python command not found: $PYTHON_BASENAME"
        return 1
    }
    echo "Creating virtualenv $PYTHON_CMD"
    $PYTHON_CMD -B -c 'import venv' 2>/dev/null && {
        hide_output_unless_error $PYTHON_CMD -m venv ${TEST_VENV_DIR} || return 1
    } || {
        hide_output_unless_error virtualenv -p $PYTHON_CMD ${TEST_VENV_DIR} || return 1
    }
    source ${TEST_VENV_DIR}/bin/activate
    PYTHON_CMD=$(command_must_exist ${PYTHON_BASENAME}) || {
        >&2 red "$pyver : python command not found: $PYTHON_BASENAME"
        return 1
    }

    cd ${DOCKER_MOUNTPOINT}
    ${CLEAN_BUILD_SCRIPT}
    echo "Installing $PY_MODULE in virtualenv using $PYTHON_CMD -m pip install ."
    unset PYTHONDONTWRITEBYTECODE
    hide_output_unless_error $PYTHON_CMD -m pip install . || {
        deactivate
        return 1
    }
    export PYTHONDONTWRITEBYTECODE=Y
    ${CLEAN_BUILD_SCRIPT}

    echo "Running tests"
    __run_tests $pyver
    echo "Uninstalling $PY_MODULE in virtualenv using $PYTHON_CMD -m pip"
    hide_output_unless_error $PYTHON_CMD -m pip uninstall -y $PY_MODULE || {
        deactivate
        return 1
    }

    cd ${DOCKER_MOUNTPOINT}
    ${CLEAN_BUILD_SCRIPT}
    echo "Installing $PY_MODULE in virtualenv using $PYTHON_CMD setup.py"
    unset PYTHONDONTWRITEBYTECODE
    hide_output_unless_error $PYTHON_CMD setup.py install || {
        deactivate
        return 1
    }
    export PYTHONDONTWRITEBYTECODE=Y
    ${CLEAN_BUILD_SCRIPT}

    echo "Running tests"
    __run_tests $pyver

    echo "Uninstalling $PY_MODULE in virtualenv using $PYTHON_CMD -m pip"
    hide_output_unless_error $PYTHON_CMD -m pip uninstall -y $PY_MODULE || {
        deactivate
        return 1
    }



    [[ -n "${GIT_URL:-}" ]] || return 0

    cd ${DOCKER_MOUNTPOINT}
    ${CLEAN_BUILD_SCRIPT}
    echo "Installing $PY_MODULE in virtualenv using $PYTHON_CMD -m pip install git+GIT_URL"
    unset PYTHONDONTWRITEBYTECODE
    hide_output_unless_error $PYTHON_CMD -m pip install git+${GIT_URL} || {
        deactivate
        return 1
    }
    export PYTHONDONTWRITEBYTECODE=Y
    ${CLEAN_BUILD_SCRIPT}

    echo "Running tests"
    __run_tests $pyver
    echo "Uninstalling $PY_MODULE in virtualenv using $PYTHON_CMD -m pip"
    hide_output_unless_error $PYTHON_CMD -m pip uninstall -y $PY_MODULE || {
        deactivate
        return 1
    }

    deactivate
    rm -rf ${TEST_VENV_DIR}
}

function inplace_build_ant_test_1_pyver() {
    # $1: PYVER - guaranteed to be in TAG_PYVER and have valid image in TAG_IMAGE
    [[ $# -lt 1 ]] && {
        >&2 red "Usage: run_1_in_venv PYTHON_VERSION_TAG"
        return 1
    }
    local pyver=$1
    PYTHON_BASENAME=${TAG_PYVER[$pyver]}
    PYTHON_CMD=$(command_must_exist ${PYTHON_BASENAME}) || {
        >&2 red "$pyver : python command not found: $PYTHON_BASENAME"
        return 1
    }

    echo "---------- Inplace build and test with $pyver -----------------"
    cd ${DOCKER_MOUNTPOINT}
    ${CLEAN_BUILD_SCRIPT}
    export PYTHONDONTWRITEBYTECODE=Y
    ${CYTHONIZE_SCRIPT}
    ${INPLACE_BUILD_SCRIPT}
    ${CLEAN_BUILD_SCRIPT}

    ${PROG_DIR}/run_func_tests.sh $pyver
}


function pip_install_user_1_pyver() {
    # $1: PYVER - guaranteed to be in TAG_PYVER and have valid image in TAG_IMAGE
    [[ $# -lt 1 ]] && {
        >&2 red "Usage: pip_install_user_1_pyver PYTHON_VERSION_TAG"
        return 1
    }
    local pyver=$1
    PYTHON_BASENAME=${TAG_PYVER[$pyver]}
    PYTHON_CMD=$(command_must_exist ${PYTHON_BASENAME}) || {
        >&2 red "$pyver : python command not found: $PYTHON_BASENAME"
        return 1
    }

    cd ${DOCKER_MOUNTPOINT}
    ${CLEAN_BUILD_SCRIPT}
    echo "Installing $PY_MODULE using $PYTHON_CMD -m pip install --user ."
    unset PYTHONDONTWRITEBYTECODE
    hide_output_unless_error $PYTHON_CMD -m pip install --user . || {
        return 1
    }
    export PYTHONDONTWRITEBYTECODE=Y
    ${CLEAN_BUILD_SCRIPT}

    echo "Running tests"
    __run_tests $pyver
    echo "Uninstalling $PY_MODULE using $PYTHON_CMD -m pip"
    hide_output_unless_error $PYTHON_CMD -m pip uninstall -y $PY_MODULE || {
        return 1
    }
}


# ------------------------------------------------------------------------
# Actual script starts after this
# ------------------------------------------------------------------------

echo "Running as $(id -un)"
echo "Running in $(distro_name)"

must_be_in_docker

# Disable pip warnings that are irrelevant here
export PIP_DISABLE_PIP_VERSION_CHECK=1
export PIP_NO_PYTHON_VERSION_WARNING=1
export PIP_ROOT_USER_ACTION=ignore

CYTHONIZE_SCRIPT="${PROG_DIR}"/cythonize.sh
CLEAN_BUILD_SCRIPT="${PROG_DIR}"/clean_build.sh
INPLACE_BUILD_SCRIPT="${PROG_DIR}"/inplace_build.sh

SRC="${PY_MODULE}/${EXTENSION_NAME}.c"
[[ -f "$SRC" ]] || {
    $CYTHONIZE_SCRIPT || {
        # Could fail if cython3 was not found in this container
        >&2 red "C source not found: ${SRC}. Running cythonize.sh failed"
        exit 1
    }
}

# This script does not launch docker containers
VALID_PYVER=$(process_std_cmdline_args no yes $@)

for p in $VALID_PYVER
do
    [[ -z "${__MINIMAL_TESTS:-}" ]] && {
        run_1_in_venv $p
        ${CLEAN_BUILD_SCRIPT}
        inplace_build_ant_test_1_pyver $p
        ${CLEAN_BUILD_SCRIPT}
    }
    pip_install_user_1_pyver $p
    ${CLEAN_BUILD_SCRIPT}
done
