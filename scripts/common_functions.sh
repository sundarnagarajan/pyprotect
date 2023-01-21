#!/bin/bash
set -e -u -o pipefail
PROG_DIR=$(readlink -f $(dirname $BASH_SOURCE))
source "${PROG_DIR}"/generic_bash_functions.sh

source "$PROG_DIR"/config_source_validate.sh

function hide_output_unless_error() {
    # Runs arguments and shows output only if there is an error
    [[ $# -lt 1 ]] && return
    local ret=0
    local out=""
    set +e
    out=$($@ 2>&1)
    ret=$?
    set -e
    [[ $ret -ne 0 ]] && {
        >&2 red "$out"
        return $ret
    }
    return 0
}

function docker_image_must_exist() {
    # $1: image name
    [[ $# -lt  1 ]] && {
        >&2 red "Usage: docker_image_must_exist <image_name>"
        return 1
    }
    docker image inspect "$1" 1>/dev/null 2>&1 || {
        >&2 red "Docker image not found: $1"
        return 1
    }
}

function running_in_docker() {
    # Returns: 0 if running in docker; 1 otherwise
    grep -q '/init\.scope$' /proc/1/cgroup && return 1 || return 0
}

function must_be_in_docker() {
    running_in_docker || {
        >&2 red "Not running in docker"
        return 1
    } && return 0
}

function must_not_be_in_docker() {
    running_in_docker && {
        >&2 red "Running in docker, not on bare metal"
        return 1
    } || return 0
}

function need_docker_command() {
    command -v docker 1>/dev/null 2>&1 || {
        >&2 red "docker command is required, but not found"
        return 1
    }
    return 0
}

function command_must_exist() {
    # $1: command
    [[ $# -lt 1 ]] && return 1
    command -v $1 2>&1
}

function restore_file_ownership() {
    # $1: mandatory: path to reference file
    # $2+ files to chown
    # If not root, cannot chown anyway
    [[ $(id -u) -ne 0 ]] && return 0
    [[ $# -lt 1 ]] && {
        >&2 red "Usage: restore_ownership <ref_file_path> [files to chown]"
        return 0
    }
    local ref_file=$1
    shift
    [[ $# -lt 1 ]] && return 0
    [[ -f "$ref_file" ]] || {
        >&2 red "restore_ownership: ref file not found: $ref_file"
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

function need_minimum_version() {
    # $1: existing_ver (mandatory)
    # $2: minimim_ver required (mandatory)
    # $3: program_name (optional - used only in error message)
    [[ $# -lt 2 ]] && {
        >&2 red "Usage: need_minimum_version <existing_ver> <minimum_ver> [prog_name]"
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
        >&red "${prog_name} ${min_reqd}. Have ${existing}"
        return 1
    }
    return 0
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
        >&2 red "Usage: process_std_cmdline_args <images> <no_tags> [PYVER_ARGS]"
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
                            >&2 red "$pyver_arg_1: No image defined"
                            errors+=$pyver_arg_1
                            continue
                        }
                        docker_image_must_exist "$img" || {
                            errors+=$pyver_arg_1
                            continue
                        }
                    } || {
                        >&2 red "${pyver_arg_1}: No image defined"
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
        >&2 red "Unrecognized arguments: $unrecognized_list"
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
        blue "${SCRIPT_NAME}: Removed RELOCATED_DIR: $RELOCATED_DIR"
    }
    # Cleans up __RELOCATED_TESTS_DIR if set and present
    [[ -n $(declare -p __RELOCATED_TESTS_DIR 2>/dev/null) && -n "${__RELOCATED_TESTS_DIR}+_"  && -d "${__RELOCATED_TESTS_DIR}" ]] && {
        rm -rf "$__RELOCATED_TESTS_DIR"
        blue "${SCRIPT_NAME}: Removed __RELOCATED_TESTS_DIR: $__RELOCATED_TESTS_DIR"
    }
}

function relocate_source_dir() {
    # Echoes new tmp dir location to stdout
    # If __RELOCATED_DIR env var is set, does nothing

    var_empty __RELOCATED_DIR || {
        blue "${SCRIPT_NAME:-}: relocate_source_dir: __RELOCATED_DIR already set"
        return 0
    }
    local NEW_TMP_DIR=$(mktemp -d -p /tmp)
    local old_top_dir=$(readlink -f "${PROG_DIR}/..")
    (
        cd "$old_top_dir"
        cp $PROJECT_FILES ${NEW_TMP_DIR}/
        cp -a $PY_MODULE $SCRIPTS_DIR $TESTS_DIR ${NEW_TMP_DIR}/
        # Clean out .so files under $PY_MODULE
        [[ -d ${NEW_TMP_DIR}/${PY_MODULE} ]] && rm -f ${NEW_TMP_DIR}/${PY_MODULE}/*.so
    )
    export __RELOCATED_DIR=${NEW_TMP_DIR}
    export RELOCATED_DIR=${NEW_TMP_DIR}
    trap cleanup 0 1 2 3 15
    blue "${SCRIPT_NAME}: Relocated source to $__RELOCATED_DIR"
}

function relocate_tests_dir() {
    var_empty __RELOCATED_TESTS_DIR || {
        blue "${SCRIPT_NAME:-}: relocate_source_dir: __RELOCATED_DIR already set"
        return 0
    }
    local NEW_TMP_DIR=$(mktemp -d -p /tmp)

    cp -a "${RELOCATED_DIR}"/$TESTS_DIR/. "$NEW_TMP_DIR"/
    chmod -R go+rX "$NEW_TMP_DIR"
    export __RELOCATED_TESTS_DIR=${NEW_TMP_DIR}
    trap cleanup 0 1 2 3 15
    blue "${SCRIPT_NAME}: Relocated tests to $__RELOCATED_TESTS_DIR"
}

function run_1_cmd_in_relocated_dir() {
    # $@ : command to execute
    # Needs following vars set:
    #   RELOCATED_DIR
    #   CLEAN_BUILD_SCRIPT
    [[ $# -lt 1 ]] && {
        >&2 red "Usage: run_1_cmd_in_relocated_dir <cmd> [args...]"
        return 1
    }
    var_empty RELOCATED_DIR && {
        >&2 red "${SCRIPT_NAME:-}: run_1_cmd_in_relocated_dir: Needs RELOCATED_DIR set"
        return 1
    }
    var_empty CLEAN_BUILD_SCRIPT && {
        >&2 red "run_1_cmd_in_relocated_dir: Needs CLEAN_BUILD_SCRIPT set"
        return 1
    }
    cd ${RELOCATED_DIR}
    ${CLEAN_BUILD_SCRIPT}
    echo -e "${SCRIPT_NAME:-}: ($(id -un)): $@"
    hide_output_unless_error $@ || return 1
    ${CLEAN_BUILD_SCRIPT}
}

function create_activate_venv() {
    # $1: PYVER
    # $2: VENV_DIR
    # Needs following vars set:
    #   SCRIPT_NAME (optional)
    [[ $# -lt 2 ]] && {
        >&2 red "Usage: run_1_in_venv PYTHON_VERSION_TAG VENV_DIR"
        return 1
    }
    local pyver=$1
    local VENV_DIR=$2
    local PYTHON_BASENAME=${TAG_PYVER[$pyver]}

    echo "${SCRIPT_NAME:-}: Clearing virtualenv dir"
    rm -rf ${VENV_DIR}
    local PYTHON_CMD=$(command_must_exist ${PYTHON_BASENAME}) || {
        >&2 red "$pyver : python command not found: $PYTHON_BASENAME"
        return 1
    }
    echo "${SCRIPT_NAME:-}: Creating virtualenv $PYTHON_CMD"
    $PYTHON_CMD -B -c 'import venv' 2>/dev/null && {
        hide_output_unless_error $PYTHON_CMD -m venv ${VENV_DIR} || return 1
    } || {
        hide_output_unless_error virtualenv -p $PYTHON_CMD ${VENV_DIR} || return 1
    }
    source ${VENV_DIR}/bin/activate
    command_must_exist ${PYTHON_BASENAME} 1>/dev/null || {
        >&2 red "${SCRIPT_NAME:-}: $pyver : python command not found: $PYTHON_BASENAME"
        return 1
    }
}

function run_tests_in_relocated_dir() {
    # Needs following vars set:
    #   __RELOCATED_TESTS_DIR - set in relocate_tests
    var_empty __RELOCATED_TESTS_DIR && {
        >&2 red "${SCRIPT_NAME:-}: __RELOCATED_TESTS_DIR not set. relocate_tests not run."
        return 1
    }
    local local_test_dir=${__RELOCATED_TESTS_DIR}
    [[ -f "$local_test_dir"/$TEST_MODULE_FILENAME ]] || {
        >&2 red "${SCRIPT_NAME:-}: test module not found ${local_test_dir}/${TEST_MODULE_FILENAME}"
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
        >&2 red "${SCRIPT_NAME}: $pyver : python command not found: $PYTHON_BASENAME"
        return 1
    }
    [[ -z "$PYTHON_CMD" ]] && {
        >&2 red "${SCRIPT_NAME}: $pyver : python command not found: $PYTHON_BASENAME"
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

