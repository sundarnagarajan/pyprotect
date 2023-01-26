#!/bin/bash
set -e -u -o pipefail
PROG_DIR=$(readlink -f $(dirname $BASH_SOURCE))
source "${PROG_DIR}"/generic_bash_functions.sh
source "$PROG_DIR"/config_distro_source_validate.sh

function docker_image_must_exist() {
    # $1: image name
    [[ $# -lt  1 ]] && {
        >&2 red "$(basename ${BASH_SOURCE}): Usage: ${FUNCNAME[0]} <image_name>"
        return 1
    }
    docker image inspect "$1" 1>/dev/null 2>&1 || {
        >&2 red "$(basename ${BASH_SOURCE[1]})(${FUNCNAME[1]}): Docker image not found: $1"
        return 1
    }
}

function running_in_docker() {
    # Returns: 0 if running in docker; 1 otherwise
    grep -q '/init\.scope$' /proc/1/cgroup && return 1 || return 0
}

function must_be_in_docker() {
    running_in_docker || {
        >&2 red "$(basename ${BASH_SOURCE[1]})(${FUNCNAME[1]}): Not running in docker"
        return 1
    } && return 0
}

function must_not_be_in_docker() {
    running_in_docker && {
        >&2 red "$(basename ${BASH_SOURCE[1]})(${FUNCNAME[1]}): Running in docker, not on bare metal"
        return 1
    } || return 0
}

function need_docker_command() {
    command -v docker 1>/dev/null 2>&1 || {
        >&2 red "$(basename ${BASH_SOURCE[1]})(${FUNCNAME[1]}): docker command is required, but not found"
        return 1
    }
    return 0
}

function restore_file_ownership() {
    # $1: mandatory: path to reference file
    # $2+ files to chown
    # If not root, cannot chown anyway
    [[ $(id -u) -ne 0 ]] && return 0
    [[ $# -lt 1 ]] && {
        >&2 red "$(basename ${BASH_SOURCE}): Usage: ${FUNCNAME[0]} <ref_file_path> [files to chown]"
        return 0
    }
    local ref_file=$1
    shift
    [[ $# -lt 1 ]] && return 0
    [[ -f "$ref_file" ]] || {
        >&2 red "$(basename ${BASH_SOURCE[1]})(${FUNCNAME[1]}): ${FUNCNAME[0]}: ref file not found: $ref_file"
        return 0
    }
    ref_file=$(readlink -f "$ref_file")
    local uid_gid=$(find "$ref_file" -printf '%U:%G\n')
    while [[ $# -gt 0 ]]
    do
        chown $uid_gid "$1"
        shift
    done
}

function distro_name() {
    # Outputs multi-word string on stdout
    [[ -f /etc/os-release ]] && {
        # Run in sub-shell
            local in_docker="(Not in docker)"
        running_in_docker && in_docker="(In docker)"
        ( 
            source /etc/os-release
            echo "$PRETTY_NAME $in_docker"
        )
    }
}

function process_std_cmdline_args() {
    # $1: mandatory: yes: tags need valid images
    # $2: mandatory: yes: If no tags supplied, choose all valid TAG_PYVER tags
    # $@: PYVER args
    #
    # Outputs (stdout) unique in-order set of PYTHON_VERSION tags
    # that are guaranteed to be present in TAG_PYVER (and TAG_IMAGE based on $1
    #
    [[ $# -lt 2 ]] && {
        >&2 red "$(basename ${BASH_SOURCE[1]})(${FUNCNAME[1]}): Usage: ${FUNCNAME[0]} <images> <no_tags> [PYVER_ARGS]"
        >&2 red "    <images>:  yes: All tags need valid Docker images"
        >&2 red "    <no_tags>: yes: If no tags, choose all valid TAG_PYVER tags"
        return 1
    }
    local need_images=$1
    shift
    local add_tags_if_missing=$1
    shift

    declare -a chosen_pyver_args=( "$@" )
    declare -a errors=()
    local pyver_list=""
    declare -A pyver_map=()
    declare -A unrecognized_map=()

    while [[ $# -gt 0 ]]
    do
        case "$1" in
            *)
                local pyver_arg_1=$1
                shift
                # Must be a PYTHON_VERSION tag
                [[ ${TAG_PYVER["$pyver_arg_1"]+_} ]] || {
                    unrecognized_map["$pyver_arg_1"]=yes
                    errors+=$pyver_arg_1
                    continue
                }
                [[ "$need_images" = "yes" ]] && {
                    [[ ${TAG_IMAGE["$pyver_arg_1"]+_} ]] && {
                        local img=${TAG_IMAGE["$pyver_arg_1"]}
                        [[ -z "$img" ]] && {
                            >&2 red "$(basename ${BASH_SOURCE[1]})(${FUNCNAME[1]}): $pyver_arg_1: No image defined"
                            errors+=$pyver_arg_1
                            continue
                        }
                        docker_image_must_exist "$img" || {
                            errors+=$pyver_arg_1
                            continue
                        }
                    } || {
                        >&2 red "$(basename ${BASH_SOURCE[1]})(${FUNCNAME[1]}): ${pyver_arg_1}: No image defined"
                        errors+=$pyver_arg_1
                        continue
                    }
                }
                # It is in TAG_PYVER and has valid image if need_images=yes
                [[ ${pyver_map["$pyver_arg_1"]+_} ]] || {
                    pyver_map["$pyver_arg_1"]=yes
                    [[ -z "$pyver_list" ]] && {
                        pyver_list="$pyver_arg_1"
                    } || {
                        pyver_list="$pyver_list $pyver_arg_1"
                    }
                }
                ;;
        esac
    done

    # Show the unrecognized args as errors
    local unrecognized_list=""
    for k in "${!unrecognized_map[@]}"
    do
        unrecognized_list="$unrecognized_list $k"
    done
    [[ -n "$unrecognized_list" ]] && {
        >&2 red "$(basename ${BASH_SOURCE[1]})(${FUNCNAME[1]}): ${FUNCNAME[0]}: Unrecognized arguments: $unrecognized_list"
    }

    # If PYVER args were provided, any errors are fatal
    [[ ${#chosen_pyver_args[@]} -ne 0 && ${#errors[@]} -ne 0 ]] && return 1

    # add tags if missing if no PYVER args were provided
    [[ ${#chosen_pyver_args[@]} -eq 0 && -z "$pyver_list" && "$add_tags_if_missing" = "yes" ]] && {
        # for k in "${!TAG_PYVER[@]}"
        for k in $(echo ${!TAG_PYVER[@]} | tr ' ' '\n' | LC_ALL=C sort)
        do
            # When automatically adding defined tags, do not show errors
            [[ "$need_images" = "yes" ]] && {
                [[ ${TAG_IMAGE["$k"]+_} ]] && {
                    [[ -z ${TAG_IMAGE["$k"]} ]] && continue
                    docker_image_must_exist ${TAG_IMAGE["$k"]} || continue
                } || continue
            }
            [[ -z "$pyver_list" ]] && {
                pyver_list="$k"
            } || {
                pyver_list="$pyver_list $k"
            }
        done
    }
    echo "$pyver_list"
}

function cleanup() {
    # Cleans up RELOCATED_DIR if set and present
    [[ -n $(declare -p RELOCATED_DIR 2>/dev/null) && -n "${RELOCATED_DIR}+_"  && -d "${RELOCATED_DIR}" ]] && {
        rm -rf "$RELOCATED_DIR"
        [[ $VERBOSITY -lt 7 ]] || echo "${SCRIPT_NAME}: Removed RELOCATED_DIR: $RELOCATED_DIR"
    }
    # Cleans up __RELOCATED_TESTS_DIR if set and present
    [[ -n $(declare -p __RELOCATED_TESTS_DIR 2>/dev/null) && -n "${__RELOCATED_TESTS_DIR}+_"  && -d "${__RELOCATED_TESTS_DIR}" ]] && {
        rm -rf "$__RELOCATED_TESTS_DIR"
        [[ $VERBOSITY -lt 7 ]] || echo "${SCRIPT_NAME}: Removed __RELOCATED_TESTS_DIR: $__RELOCATED_TESTS_DIR"
    }
}

function relocate_source_dir() {
    # Echoes new tmp dir location to stdout
    # If __RELOCATED_DIR env var is set, does nothing

    var_empty __RELOCATED_DIR || {
        [[ $VERBOSITY -lt 4 ]] || blue "${SCRIPT_NAME:-}: ${FUNCNAME[0]}: __RELOCATED_DIR already set"
        return 0
    }
    local NEW_TMP_DIR=$(mktemp -d -p /tmp)
    local old_top_dir=$(readlink -f "${SOURCE_TOPLEVEL_DIR}")
    (
        cd "$old_top_dir"
        cp $PROJECT_FILES ${NEW_TMP_DIR}/
        cp -a $PY_MODULE $TOPLEVEL_SUBDIR $TESTS_DIR ${NEW_TMP_DIR}/
        # Clean out .so files under $PY_MODULE
        [[ -d ${NEW_TMP_DIR}/${PY_MODULE} ]] && rm -f ${NEW_TMP_DIR}/${PY_MODULE}/*.so
    )
    export __RELOCATED_DIR=${NEW_TMP_DIR}
    export RELOCATED_DIR=${NEW_TMP_DIR}
    trap cleanup 0 1 2 3 15
    [[ $VERBOSITY -lt 6 ]] || echo "${SCRIPT_NAME}: Relocated source to $__RELOCATED_DIR"
}

function relocate_tests_dir() {
    var_empty __RELOCATED_TESTS_DIR || {
        [[ $VERBOSITY -lt 4 ]] || blue "${SCRIPT_NAME:-}: ${FUNCNAME[0]}: __RELOCATED_DIR already set"
        return 0
    }
    local NEW_TMP_DIR=$(mktemp -d -p /tmp)

    cp -a "${RELOCATED_DIR}"/$TESTS_DIR/. "$NEW_TMP_DIR"/
    chmod -R go+rX "$NEW_TMP_DIR"
    export __RELOCATED_TESTS_DIR=${NEW_TMP_DIR}
    trap cleanup 0 1 2 3 15
    [[ $VERBOSITY -lt 6 ]] || echo "${SCRIPT_NAME}: Relocated tests to $__RELOCATED_TESTS_DIR"
}

function run_1_cmd_in_relocated_dir() {
    # $@ : command to execute
    # Needs following vars set:
    #   RELOCATED_DIR
    #   CLEAN_BUILD_SCRIPT
    [[ $# -lt 1 ]] && {
        >&2 red "$(basename ${BASH_SOURCE[1]})(${FUNCNAME[1]}): Usage: ${FUNCNAME[0]} <cmd> [args...]"
        return 1
    }
    var_empty RELOCATED_DIR && {
        >&2 red "$(basename ${BASH_SOURCE[1]})(${FUNCNAME[1]}): ${FUNCNAME[0]}: Needs RELOCATED_DIR set"
        return 1
    }
    var_empty CLEAN_BUILD_SCRIPT && {
        >&2 red "$(basename ${BASH_SOURCE[1]})(${FUNCNAME[1]}): ${FUNCNAME[0]}: Needs CLEAN_BUILD_SCRIPT set"
        return 1
    }
    cd ${RELOCATED_DIR}
    ${CLEAN_BUILD_SCRIPT}
    [[ $VERBOSITY -lt 3 ]] || echo -e "${SCRIPT_NAME:-}: ($(id -un)): $@"
    hide_output_unless_error $@ || return 1
    ${CLEAN_BUILD_SCRIPT}
}

function create_activate_venv() {
    # $1: PYVER
    # $2: VENV_DIR
    # Needs following vars set:
    #   SCRIPT_NAME (optional)
    [[ $# -lt 2 ]] && {
        >&2 red "$(basename ${BASH_SOURCE}): Usage: ${FUNCNAME[0]} PYTHON_VERSION_TAG VENV_DIR"
        return 1
    }
    local pyver=$1
    local VENV_DIR=$2
    local PYTHON_BASENAME=${TAG_PYVER[$pyver]}

    [[ $VERBOSITY -lt 3 ]] || echo "${SCRIPT_NAME:-}: Clearing virtualenv dir"
    rm -rf ${VENV_DIR}
    local PYTHON_CMD=$(command_must_exist ${PYTHON_BASENAME}) || {
        >&2 red "$(basename ${BASH_SOURCE[1]})(${FUNCNAME[1]}): $pyver : python command not found: $PYTHON_BASENAME"
        return 1
    }
    [[ $VERBOSITY -lt 3 ]] || echo "${SCRIPT_NAME:-}: Creating virtualenv $PYTHON_CMD"
    $PYTHON_CMD -B -c 'import venv' 2>/dev/null && {
        hide_output_unless_error $PYTHON_CMD -m venv ${VENV_DIR} || return 1
    } || {
        hide_output_unless_error virtualenv -p $PYTHON_CMD ${VENV_DIR} || return 1
    }
    source ${VENV_DIR}/bin/activate
    command_must_exist ${PYTHON_BASENAME} 1>/dev/null || {
        >&2 red "$(basename ${BASH_SOURCE[1]})(${FUNCNAME[1]}): $pyver : python command not found: $PYTHON_BASENAME"
        return 1
    }
}

function run_tests_in_relocated_dir() {
    # Needs following vars set:
    #   __RELOCATED_TESTS_DIR - set in relocate_tests
    var_empty __RELOCATED_TESTS_DIR && {
        >&2 red "$(basename ${BASH_SOURCE[1]})(${FUNCNAME[1]}): __RELOCATED_TESTS_DIR not set. relocate_tests not run."
        return 1
    }
    local local_test_dir=${__RELOCATED_TESTS_DIR}
    [[ -f "$local_test_dir"/$TEST_MODULE_FILENAME ]] || {
        >&2 red "$(basename ${BASH_SOURCE[1]})(${FUNCNAME[1]}): test module not found ${local_test_dir}/${TEST_MODULE_FILENAME}"
        return 1
    }
    cd /
    __TESTS_DIR=$local_test_dir "$PROG_DIR"/run_func_tests.sh $pyver
}

function run_std_tests_in_relocated_dir() {
    # $1: PYVER
    local pyver=$1
    local PYTHON_BASENAME=${TAG_PYVER[$pyver]}
    local PYTHON_CMD=$(command_must_exist ${PYTHON_BASENAME}) || {
        >&2 red "$(basename ${BASH_SOURCE[1]})(${FUNCNAME[1]}): $pyver : python command not found: $PYTHON_BASENAME"
        return 1
    }
    [[ -z "$PYTHON_CMD" ]] && {
        >&2 red "$(basename ${BASH_SOURCE[1]})(${FUNCNAME[1]}): $pyver : python command not found: $PYTHON_BASENAME"
        return 1
    }
    run_1_cmd_in_relocated_dir "$PYTHON_CMD" -m pip uninstall -y $PIP_NAME

    run_1_cmd_in_relocated_dir $PYTHON_CMD -m pip install .
    run_tests_in_relocated_dir
    run_1_cmd_in_relocated_dir "$PYTHON_CMD" -m pip uninstall -y $PIP_NAME

    run_1_cmd_in_relocated_dir $PYTHON_CMD setup.py install
    run_tests_in_relocated_dir
    run_1_cmd_in_relocated_dir "$PYTHON_CMD" -m pip uninstall -y $PIP_NAME

    [[ -n "${GIT_URL:-}" ]] || return 0

    run_1_cmd_in_relocated_dir $PYTHON_CMD -m pip install git+${GIT_URL}
    run_tests_in_relocated_dir
    run_1_cmd_in_relocated_dir "$PYTHON_CMD" -m pip uninstall -y $PIP_NAME
}

# ------------------------------------------------------------------------
# Version-related functions that use PYTHON CODE embedded in shell to
# get "proper" version comparisons using packaging.version.parse or
# distutils.version.LooseVersion - what setuptools uses
# ------------------------------------------------------------------------

function sort_versions() {
    # Reads stdin, writes stdout
    # Reads one version per line, writes one version per line
    # Can fail (return 1) if no python command was found
    # Returns:
    #   0  : On success
    #  -1  : No python3 command was found
    #   2  : packaging.version not found
    local PYCMD=
    # Cannot use [[ cmd ]] construct for this
    if ! PYCMD=$(command -v python3); then
        >&2 red "$(basename ${BASH_SOURCE[1]})(${FUNCNAME[1]}): ${FUNCNAME[0]}: No python3 found"
        return -1
    fi
    local PY_CODE='
import sys
try:
    from packaging.version import parse as verfn
except:
    sys.stderr.write("packaging.version not found")
    exit(2)

l = []
while True:
    x = sys.stdin.readline()
    if not x:
        break
    # Versions never have spaces
    x = x.rstrip("\n").strip()
    l.append(x)

l.sort(key=verfn)
print("\n".join(l))
'
    $PYCMD -c "$PY_CODE" || return $?
    return 0
}

function compare_versions() {
    # Compares two version strings using a comparison operator
    # Returns 0 if comparison succeeded; 1 otherwise
    # $1: operator: Mandatory: one of '<', '<=' '==', '>=' '>'
    # $2: ver_val: Mandatory, non-empty
    # $3: ref_ver: optional
    # Returns:
    #   0  : If comparison succeeded, or no ref_ver was provided
    #   1  : If ref_ver was provided and comparison was done and failed
    #  -1  : No python3 command was found
    #   2  : packaging.version not found
    #   3  : Bad operator
    #   4  : Bad command line args
    #   5  : ver_val is not a valid version string
    #   6  : ref_ver is not a valid version string

    # Following all succeed (>=):
    #     compare_versions '>=' '3.5' '3.5'
    #     compare_versions '>=' '3.5' '3.4'
    #     compare_versions '>=' '3.5.1' '3.5'
    # Following all succeed (<):
    #     compare_versions '>=' '3.5.0' '3.5'
    #     compare_versions '<' '3.5' '3.6'
    #     compare_versions '<' '3.5' '3.5.2'

    # Following all FAIL (>=):
    # packaging.version (and setuptools) treats 1.2-xNN SMALLER than
    # 1.2 when x is a letter and NN is numeric
    #     compare_versions '>='  3.0.0-a11 3.0
    #     compare_versions '>='  3.0.0-11def 3.0
    #     compare_versions '>='  3.0.0a11 3.0
    #     compare_versions '>='  3.0.0b11 3.0
    #     compare_versions '>='  3.0.0g11 3.0

    # Following all FAIL (<):
    # packaging.version (and setuptools) treats 1.2 as EQUAL to 1.2.0
    #     compare_versions '<'  3.5 3.5.0

    # Following all FAIL (<):
    # packaging.version (and setuptools) treats 1.2-xNN SMALLER than
    # 1.2 when x is a letter and NN is numeric
    #     compare_versions '<'  3.0 3.0.0-a11
    #     compare_versions '<'  3.0 3.0.0-11def
    #     compare_versions '<'  3.0 3.0.0a11
    #     compare_versions '<'  3.0 3.0.0b11
    #     compare_versions '<'  3.0 3.0.0g11

    local PYCMD=
    # Cannot use [[ cmd ]] construct for this
    if ! PYCMD=$(command -v python3); then
        >&2 red "${SCRIPT_NAME}: ${FUNCNAME[0]}: No python3 found"
        return -1
    fi
    local PY_CODE='
# Need to understand, learn and use version numbering logic
# implemented in packaging.version - especially when comparing
# version numbers in setup.py, python version numbers and
# package version numbers. distutils.version.LooseVersion is
# just ... ... LOOSE
# Works on all python3 versions (tested 3.5+)
# python3 is universally available - even in manylinux1 image

import sys
try:
    # from packaging.version import parse as verfn
    from packaging.version import Version as verfn
except:
    sys.stderr.write("packaging.version not found")
    exit(2)

if len(sys.argv) < 3:
    sys.stderr.write("Insufficient arguments")
    exit(4)

operator = sys.argv[1].strip()
if operator not in ("<", "<=" "==", ">=", ">"):
    sys.stderr.write("Invalid operator: %s" % (operator,))
    exit(3)

# Versions never have spaces
ver_val = sys.argv[2].strip()
if not ver_val:
    sys.stderr.write("ver_val not provided")
    exit(2)
if len(sys.argv) < 4:
    exit(0)

# Versions never have spaces
ref_ver = sys.argv[3].strip()

# NO ref_ver means check always succeeds
if not ref_ver:
    exit(0)

try:
    ver_val = verfn(ver_val)
except:
    sys.stderr.write("ver_val: invalid version: %s" % (ver_val,))
    exit(5)
try:
    ref_ver = verfn(ref_ver)
except:
    sys.stderr.write("ref_ver: invalid version: %s" % (ref_ver,))
    exit(6)

# Using eval (naughty!) - use var names not values
eval_str = "ver_val %s ref_ver" % (operator,)
if eval(eval_str):
    exit(0)
exit(1)
'
    $PYCMD -c "$PY_CODE" "$@" || return $?
    return 0
}

function version_gt_eq() {
    # Checks that a ver_val is GREATER THAN OR EQUAL to an optional ref_ver
    # $1: ver_val: Mandatory, non-empty
    # $2: ref_ver: optional
    # Returns:
    #   0  : If comparison succeeded, or no ref_ver was provided
    #   1  : If ref_ver was provided and comparison was done and failed
    #  -1  : No python3 command was found
    #   2  : packaging.version not found
    #   3  : Bad operator
    #   4  : Bad command line args
    #   5  : ver_val is not a valid version string
    #   6  : ref_ver is not a valid version string
    # With no ref_ver always succeeds

    local ret=0
    compare_versions '>=' $@ || ret=$?
    [[ $ret -gt 2 ]] && {
        >&2 echo ": ${SCRIPT_NAME}: Usage: ${FUNCNAME[0]} <ver_val> [ref_ver]"
    }
    return $ret
}

function version_lt() {
    # Checks that a ver_val is LESS THAN an optional ref_ver
    # $1: ver_val: Mandatory, non-empty
    # $2: ref_ver: optional
    # Returns:
    #   0  : If comparison succeeded, or no ref_ver was provided
    #   1  : If ref_ver was provided and comparison was done and failed
    #  -1  : No python3 command was found
    #   2  : packaging.version not found
    #   3  : Bad operator
    #   4  : Bad command line args
    #   5  : ver_val is not a valid version string
    #   6  : ref_ver is not a valid version string
    local ret=0
    compare_versions '<' $@ || ret=$?
    [[ $ret -gt 2 ]] && {
        >&2 echo ": ${SCRIPT_NAME}: Usage: ${FUNCNAME[0]} <ver_val> [ref_ver]"
    }
    return $ret
}

function need_minimum_version() {
    # $1: existing_ver (mandatory)
    # $2: minimim_ver required (mandatory)
    # $3: program_name (optional - used only in error message)
    [[ $# -lt 2 ]] && {
        >&2 red "$(basename ${BASH_SOURCE}): Usage: ${FUNCNAME[0]} <existing_ver> <minimum_ver> [prog_name]"
        return 1
    }
    local existing=$1
    local min_reqd=$2
    local prog_name="Need: "
    [[ $# -gt 2 ]] && {
        prog_name="${3} : Need: "
    }
    local highest=$(echo -e "${existing}\n${min_reqd}" | sort -r -V | head -1)
    [[ "$highest" = "$existing" ]] || {
        >&red "$(basename ${BASH_SOURCE[1]})(${FUNCNAME[1]}): ${prog_name} ${min_reqd}. Have ${existing}"
        return 1
    }
    return 0
}

function get_version() {
    # Echoes version number from VERSION.TXT to stdout
    var_empty_not_spaces FEATURES_DIR && {
        >&2 red "$(basename ${BASH_SOURCE[1]})(${FUNCNAME[1]}): ${FUNCNAME[0]}: FEATURES_DIR not set"
        return
    }
    local local_features_dir=${SOURCE_TOPLEVEL_DIR}/$FEATURES_DIR
    [[ -d "$local_features_dir" ]] || {
        >&2 red "$(basename ${BASH_SOURCE[1]})(${FUNCNAME[1]}): ${FUNCNAME[0]}: FEATURES_DIR not a directory: $local_features_dir"
        return
    }
    local local_ver_file=${local_features_dir}/VERSION.TXT
    [[ -f "$local_ver_file" ]] || {
        >&2 red "$(basename ${BASH_SOURCE[1]})(${FUNCNAME[1]}): ${FUNCNAME[0]}: Version file not found: $local_ver_file"
    }
    cat "$local_ver_file"
}

