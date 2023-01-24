#!/bin/bash
set -eu -o pipefail
PROG_DIR=$(readlink -f $(dirname $0))
SCRIPT_NAME=$(basename $0)
source "$PROG_DIR"/common_functions.sh


[[ $(id -u) -ne 0 ]] && {
    >&2 red "${SCRIPT_NAME}: Run as root"
    exit 1
}
echo "${SCRIPT_NAME}: Running in $(distro_name) as $(id -un)"
must_be_in_docker

relocate_source_dir
relocate_tests_dir
PROG_DIR="$__RELOCATED_DIR"/${SCRIPTS_DIR}
PROG_DIR=$(readlink -f "$PROG_DIR")
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
        su $NORMAL_USER -c "__RELOCATED_DIR=${RELOCATED_DIR} __RELOCATED_TESTS_DIR=${__RELOCATED_TESTS_DIR} ${PROG_DIR}/venv_test_install_inplace_in_docker.sh $p" || {
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
        run_std_tests_in_relocated_dir $p || {
            [[ -n "$PYVER_CHOSEN" ]] && exit 1 || {
                ${CLEAN_BUILD_SCRIPT}
                continue
            }
        }
    }

done
${CLEAN_BUILD_SCRIPT}

