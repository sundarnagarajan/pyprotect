#!/bin/bash
# --------------------------------------------------------------------
# DO NOT CHANGE ANYTHING in this file
# Only change 'config.sh' and 'docker/config_docker_*.sh'
#
# Needs generic_bash_functions.sh sourced before this file is sourced
#
# --------------------------------------------------------------------
SCRIPT_DIR=$(readlink -f $(dirname $BASH_SOURCE))


function get_config_vars_from_source() {
    # Here are what we can get 'DRY' from the source:
    #
    # 1. PY_MODULE from setup.py
    # grep '^PY_MODULE[[:space:]][[:space:]]*=' setup.py | awk -F= '{print $2}' | sed -e "s/'//g" -e 's/"//g' -e 's/ //g'
    #
    #
    # 2. PIP_NAME from setup.cfg
    # grep '^name[[:space:]][[:space:]]*=' setup.cfg | awk -F= '{print $2}' | sed -e 's/ //g'
    #
    # DEFS_FILE_BASENAME from PY_MODULE/__init__.py
    # grep '^DEFS_FILE_BASENAME[[:space:]][[:space:]]*=' pyprotect/__init__.py | awk -F= '{print $2}' | sed -e "s/'//g" -e 's/"//g' -e 's/ //g'
    #
    # $PY_MODULE/$DEFS_FILE_BASENAME contains (ini form in section 'defs')
    # EXTENSION_NAME
    # VERSION
    #
    # Should be called AFTER setting SOURCE_TOPLEVEL_DIR
    # Should be called AFTER sourcing config.sh and unsetting the following
    # variables:
    #   PY_MODULE
    #   PIP_NAME
    #   DEFS_FILE_BASENAME
    #   EXTENSION_NAME
    #   VERSION
    #
    cd "${SOURCE_TOPLEVEL_DIR}"
    for v in PY_MODULE PIP_NAME DEFS_FILE_BASENAME EXTENSION_NAME VERSION
    do
        unset $v
    done

    PY_MODULE=$(grep '^PY_MODULE[[:space:]][[:space:]]*=' "${SOURCE_TOPLEVEL_DIR}"/setup.py | awk -F= '{print $2}' | sed -e "s/'//g" -e 's/"//g' -e 's/ //g')
    PIP_NAME=$(grep '^name[[:space:]][[:space:]]*=' "${SOURCE_TOPLEVEL_DIR}"/setup.cfg | awk -F= '{print $2}' | sed -e 's/ //g')
    DEFS_FILE_BASENAME=$(grep '^DEFS_FILE_BASENAME[[:space:]][[:space:]]*=' "${SOURCE_TOPLEVEL_DIR}"/${PY_MODULE}/__init__.py | awk -F= '{print $2}' | sed -e "s/'//g" -e 's/"//g' -e 's/ //g')
    EXTENSION_NAME=$(grep '^EXTENSION_NAME[[:space:]][[:space:]]*=' "${SOURCE_TOPLEVEL_DIR}"/${PY_MODULE}/${DEFS_FILE_BASENAME} | awk -F= '{print $2}' | sed -e 's/ //g')
    VERSION=$(grep '^VERSION[[:space:]][[:space:]]*=' "${SOURCE_TOPLEVEL_DIR}"/${PY_MODULE}/${DEFS_FILE_BASENAME} | awk -F= '{print $2}' | sed -e 's/ //g')
}


# config vars are made read-only, so they are guarded by __CONFIG_SOURCED
var_declared __CONFIG_SOURCED && return
var_empty __CONFIG_SOURCED || return
errors=0

source "${SCRIPT_DIR}"/config_dirs.sh

# Unset variables that are supposed to come from config files so that
# they are never used from the environment
for v in \
    PY_MODULE \
    PIP_NAME \
    EXTENSION_NAME \
    DOCKER_MOUNTPOINT \
    DEFAULT_DISTRO \
    TAG_PYVER \
    GPG_KEY \
    CYTHONIZE_REQUIRED \
    CYTHON3_PROG_NAME \
    CYTHON3_PROG_NAME \
    TESTS_DIR \
    PROJECT_FILES \
    TEST_MODULE_FILENAME \
    TAG_IMAGE \
    DOCKERFILE_IMAGE \
    CYTHON_DOCKER_FILE \
    CYTHON3_DOCKER_IMAGE \
    VERBOSITY
do
    unset $v
done

source "${SOURCE_TOPLEVEL_DIR}"/${CONFIG_DIR}/config.sh
get_config_vars_from_source

# Some variables MUST be set in config.sh - now set by get_config_vars_from_source
for v in PY_MODULE DOCKER_MOUNTPOINT DEFAULT_DISTRO TAG_PYVER GPG_KEY TEST_MODULE_FILENAME
do
    var_declared $v || {
        >&2 red "$v not set (unexpected): get_config_vars_from_source"
        errors=1
    }
done
# Somr vars should NOT be arrays
for v in PY_MODULE PIP_NAME DOCKER_MOUNTPOINT DEFAULT_DISTRO GPG_KEY TEST_MODULE_FILENAME TESTS_DIR PROJECT_FILES VERBOSITY
do
    var_declared $v && {
        var_is_nonarray $v || {
        >&2 red "$v should be ordinary (non-array) (unexpected): get_config_vars_from_source"
        errors=1
        }
    }
done

var_is_map TAG_PYVER || {
    >&2 red "TAG_PYVER is not an associative array in config.sh"
    errors=1
}

# Initialize optional variables
PY_MODULE=${PY_MODULE:-}
PIP_NAME=${PIP_NAME:-$PY_MODULE}
EXTENSION_NAME=${EXTENSION_NAME:-}
DOCKER_MOUNTPOINT=${DOCKER_MOUNTPOINT:-}
DEFAULT_DISTRO=${DEFAULT_DISTRO:-}
GPG_KEY=${GPG_KEY:-}
TEST_MODULE_FILENAME=${TEST_MODULE_FILENAME:-}
VERBOSITY=${VERBOSITY:-4}
# CAN override VERBOSITY in config.sh with env var __VERBOSITY
VERBOSITY=${__VERBOSITY:-$VERBOSITY}


# Some vars must be ints
for v in VERBOSITY
do
    var_value_int $v || {
        >&2 red "$v should be an integer in config.sh (${!v})"
        errors=1
    }
done

for v in PY_MODULE DOCKER_MOUNTPOINT DEFAULT_DISTRO GPG_KEY TAG_PYVER TEST_MODULE_FILENAME
do
    var_empty $v && {
        >&2 red "$v is empty in config.sh"
        errors=1
    }
done


# Set defaults
CYTHONIZE_REQUIRED=${CYTHONIZE_REQUIRED:-no}
CYTHON3_PROG_NAME=${CYTHON3_PROG_NAME:-cython3}
TESTS_DIR=${TESTS_DIR:-tests}
TESTS_DIR=$(basename "${TESTS_DIR}")
TEST_MODULE_FILENAME=$(basename "$TEST_MODULE_FILENAME")
GIT_URL=${GIT_URL:-}
DEFAULT_PROJECT_FILES="MANIFEST.in README.md pyproject.toml setup.cfg setup.py"
PROJECT_FILES=${PROJECT_FILES:-$DEFAULT_PROJECT_FILES}
unset DEFAULT_PROJECT_FILES

# Validate vars that must be existing files / dirs
for v in TESTS_DIR PY_MODULE
do
    x="${SOURCE_TOPLEVEL_DIR}/${!v}"
    [[ -d "$x" ]] || {
        >&2 red "$v is not a directory: ${x}"
        errors=1
    }
done
for x in $PROJECT_FILES
do
    [[ -e "${SOURCE_TOPLEVEL_DIR}/${x}" ]] && {
        [[ -f "${SOURCE_TOPLEVEL_DIR}/${x}" ]] || {
            >&2 red "Project file is not a file: ${SOURCE_TOPLEVEL_DIR}/${x}"
            errors=1
        }
    } || {
        >&2 red "Project file does not exist: ${SOURCE_TOPLEVEL_DIR}/${x}"
        errors=1
    }
done

# These are related to UID / GID on the host
HOST_USERNAME=$(id -un)
HOST_GROUPNAME=$(id -gn)
HOST_UID=$(id -u)
HOST_GID=$(id -g)

# Make config entries from config.sh read-only
# Can override CYTHON3_PROG_NAME and TAG_PYVER in config_docker_<distro>.sh
readonly \
    EXTENSION_NAME CYTHONIZE_REQUIRED \
    CYTHON3_MIN_VER \
    PY_MODULE PIP_NAME DOCKER_MOUNTPOINT \
    TESTS_DIR PROJECT_FILES \
    TEST_MODULE_FILENAME \
    DEFAULT_DISTRO \
    GIT_URL GPG_KEY \
    VERBOSITY \
    HOST_USERNAME HOST_GROUPNAME HOST_UID HOST_GID 


# Source the distro-specific config_docker_XXX.sh
DISTRO=${__DISTRO:-$DEFAULT_DISTRO}
DOCKER_CONFIG_FILE=${SOURCE_TOPLEVEL_DIR}/${CONFIG_DIR}/config_distro_${DISTRO}.sh
DOCKER_CONFIG_FILE_BASENAME=$(basename "$DOCKER_CONFIG_FILE")
source "$DOCKER_CONFIG_FILE"
unset DISTRO

# Make sure required vars are set in config_docker_<distro>.sh
for v in TAG_IMAGE DOCKERFILE_IMAGE
do
    var_declared $v || {
        >&2 red "$v not set in $DOCKER_CONFIG_FILE_BASENAME"
        errors=1
    }
    var_is_map $v || {
        >&2 red "$v is not an associative array in $DOCKER_CONFIG_FILE_BASENAME"
        errors=1
    }
    var_empty $v && {
        >&2 red "$v is empty in $DOCKER_CONFIG_FILE_BASENAME"
        errors=1
    }
done

for v in CYTHON_DOCKER_FILE
do
    var_declared $v && {
        var_is_nonarray $v || {
            >&2 red "$v should be ordinary (non-array) in $DOCKER_CONFIG_FILE_BASENAME"
            errors=1
        }
    }
done

# If required, Derive CYTHON3_DOCKER_IMAGE or make sure it is set
[[ -n "${EXTENSION_NAME:-}" && "${CYTHONIZE_REQUIRED:-}" = "yes" ]] && {
    var_empty CYTHON_DOCKER_FILE && {
        >&2 red "$(basename $BASH_SOURCE): C-Extension with CYTHONIZE_REQUIRED=yes, but CYTHON_DOCKER_FILE not set"
        errors=1
    }
    [[ -n ${DOCKERFILE_IMAGE[$CYTHON_DOCKER_FILE]+_} ]] && {
        var_empty CYTHON3_DOCKER_IMAGE && CYTHON3_DOCKER_IMAGE=${DOCKERFILE_IMAGE[$CYTHON_DOCKER_FILE]}
    } || {
        >&2 red "$(basename $BASH_SOURCE): C-Extension with CYTHONIZE_REQUIRED=yes, but CYTHON3_DOCKER_IMAGE not set and $CYTHON_DOCKER_FILE not in DOCKERFILE_IMAGE"
        errors=1
    }
}

[[ $errors -ne 0 ]] && return 1
unset errors v x

# Make config entries from config.sh read-only
readonly CYTHON3_PROG_NAME TAG_PYVER  DOCKER_CONFIG_FILE
# Make config entries from config_docker_<distro>.sh read-only
readonly TAG_IMAGE DOCKERFILE_IMAGE CYTHON3_DOCKER_IMAGE

__CONFIG_SOURCED=yes
readonly __CONFIG_SOURCED
