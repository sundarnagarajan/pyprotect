#!/bin/bash

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
