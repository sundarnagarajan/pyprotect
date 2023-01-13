#!/bin/bash
set -e -u -o pipefail
PROG_DIR=$(readlink -e $(dirname $BASH_SOURCE))
source "$PROG_DIR"/config.sh

function red() {
    # Prints arguments in bold red
    ANSI_ESC=$(printf '\033')
    ANSI_RS="${ANSI_ESC}[0m"    # reset
    ANSI_HC="${ANSI_ESC}[1m"    # hicolor
    ANSI_FRED="${ANSI_ESC}[31m" # foreground red

    echo -e "${ANSI_RS}${ANSI_HC}${ANSI_FRED}$@${ANSI_RS}"
}

function hide_output_unless_error() {
    # Runs arguments and shows output only if there is an error
    local ret=0
    local out=$($@ 2>&1 || ret=$?)
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

function command_must_exist() {
    # $1: command
    [[ $# -lt 1 ]] && return 1
    command -v $1 2>&1
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

    # add_tags_if_missing if no PYVER args were provided
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
