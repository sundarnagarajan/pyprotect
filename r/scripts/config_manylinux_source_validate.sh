#!/bin/bash
# --------------------------------------------------------------------
# DO NOT CHANGE ANYTHING in this file
# Only change 'config_manylinux.sh'
#
# Needs generic_bash_functions.sh sourced before this file is sourced
#
# --------------------------------------------------------------------
SCRIPT_DIR=$(readlink -f $(dirname $BASH_SOURCE))


# config vars are made read-only, so they are guarded by __CONFIG_SOURCED
var_declared __CONFIG_MANYLINUX_SOURCED && return
var_empty __CONFIG_MANYLINUX_SOURCED || return
errors=0

# Unset variables that are supposed to come from config files so that
# they are never used from the environment
for v in \
    MANYLINUX_TAG_IMAGE \
    MANYLINUX_TAG_DOCKERFILE \
    PY3_MIN_VER \
    PY3_MAX_VER_EXCL \
    PYPY3_MIN_VER \
    PYPY3_MAX_VER_EXCL 
do
    unset $v
done

source "${SOURCE_TOPLEVEL_DIR}"/${CONFIG_DIR}/config_manylinux.sh || return 1

# Some variables MUST be set in config.sh
for v in MANYLINUX_TAG_IMAGE MANYLINUX_TAG_DOCKERFILE
do
    var_declared $v || {
        >&2 red "$v not set in config_manylinux.sh"
        errors=1
    }
done
# Some vars should NOT be arrays
for v in PY3_MIN_VER PY3_MAX_VER_EXCL PYPY3_MIN_VER PYPY3_MAX_VER_EXCL
do
    var_declared $v && {
        var_is_nonarray $v || {
        >&2 red "$v should be ordinary (non-array) in config_manylinux.sh"
        errors=1
        }
    }
done

# Some vars MUST be associative arrays
for v in MANYLINUX_TAG_IMAGE MANYLINUX_TAG_DOCKERFILE
do
    var_is_map $v || {
        >&2 red "$v is not an associative array in config_manylinux.sh"
        errors=1
    }
done

# Set defaults
PY3_MIN_VER=${PY3_MIN_VER:-}
PY3_MAX_VER_EXCL=${PY3_MAX_VER_EXCL:-}
PYPY3_MIN_VER=${PYPY3_MIN_VER:-}
PYPY3_MAX_VER_EXCL=${PYPY3_MAX_VER_EXCL:-}


[[ $errors -ne 0 ]] && return 1
unset errors v

# Make config entries from config.sh read-only
readonly \
    MANYLINUX_TAG_IMAGE \
    MANYLINUX_TAG_DOCKERFILE \
    PY3_MIN_VER \
    PY3_MAX_VER_EXCL \
    PYPY3_MIN_VER \
    PYPY3_MAX_VER_EXCL 

__CONFIG_MANYLINUX_SOURCED=yes
readonly __CONFIG_MANYLINUX_SOURCED
