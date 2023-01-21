#!/bin/bash
# --------------------------------------------------------------------
# DO NOT CHANGE ANYTHING in this file
# Only change 'config.sh' and 'docker/config_docker_*.sh'
# --------------------------------------------------------------------
SCRIPT_DIR=$(readlink -f $(dirname $BASH_SOURCE))


# config vars are made read-only, so they are guarded by __CONFIG_SOURCED
var_declared __CONFIG_SOURCED && return
var_empty __CONFIG_SOURCED || return

# Variables that belong ONLY in config.sh and cannot be overridden
# in config_docker_<distro>.sh are defaulted, validated and marked read-only

errors=0

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
    SCRIPTS_DIR \
    TESTS_DIR \
    PROJECT_FILES \
    TEST_MODULE_FILENAME \
    TAG_IMAGE \
    DOCKERFILE_IMAGE \
    CYTHON_DOCKER_FILE \
    CYTHON3_DOCKER_IMAGE
do
    unset $v
done

source ${SCRIPT_DIR}/config.sh

# Some variables MUST be set in config.sh
for v in PY_MODULE DOCKER_MOUNTPOINT DEFAULT_DISTRO TAG_PYVER GPG_KEY TEST_MODULE_FILENAME
do
    var_declared $v || {
        >&2 red "$v not set in config.sh"
        errors=1
    }
done
# Somr vars should NOT be arrays
for v in PY_MODULE PIP_NAME DOCKER_MOUNTPOINT DEFAULT_DISTRO GPG_KEY TEST_MODULE_FILENAME SCRIPTS_DIR TESTS_DIR PROJECT_FILES
do
    var_declared $v && {
        var_is_nonarray $v || {
        >&2 red "$v should be ordinary (non-array) in config.sh"
        errors=1
        }
    }
done

var_is_map TAG_PYVER || {
    >&2 red "TAG_PYVER is not an associative array in config.sh"
    errors=1
}

PY_MODULE=${PY_MODULE:-}
PIP_NAME=${PIP_NAME:-$PY_MODULE}
EXTENSION_NAME=${EXTENSION_NAME:-}
DOCKER_MOUNTPOINT=${DOCKER_MOUNTPOINT:-}
DEFAULT_DISTRO=${DEFAULT_DISTRO:-}
GPG_KEY=${GPG_KEY:-}
TEST_MODULE_FILENAME=${TEST_MODULE_FILENAME:-}

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
SCRIPTS_DIR=${SCRIPTS_DIR:-scripts}
SCRIPTS_DIR=$(basename "$SCRIPTS_DIR")
TESTS_DIR=${TESTS_DIR:-tests}
TESTS_DIR=$(basename "${TESTS_DIR}")
TEST_MODULE_FILENAME=$(basename "$TEST_MODULE_FILENAME")
GIT_URL=${GIT_URL:-}
DEFAULT_PROJECT_FILES="MANIFEST.in README.md pyproject.toml setup.cfg setup.py version.py"
PROJECT_FILES=${PROJECT_FILES:-$DEFAULT_PROJECT_FILES}
unset DEFAULT_PROJECT_FILES

# Validate vars that must be existing files / dirs
for v in SCRIPTS_DIR TESTS_DIR PY_MODULE
do
    x="${SCRIPT_DIR}/../${!v}"
    [[ -d "$x" ]] || {
        >&2 red "$v is not a directory: ${!v}"
        errors=1
    }
done
for x in $PROJECT_FILES
do
    [[ -e "${SCRIPT_DIR}/../${x}" ]] && {
        [[ -f "${SCRIPT_DIR}/../${x}" ]] || {
            >&2 red "Project file is not a file: ${SCRIPT_DIR}/../${x}"
            errors=1
        }
    } || {
        >&2 red "Project file does not exist: ${SCRIPT_DIR}/../${x}"
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
    SCRIPTS_DIR TESTS_DIR PROJECT_FILES \
    TEST_MODULE_FILENAME \
    DEFAULT_DISTRO \
    GIT_URL GPG_KEY \
    HOST_USERNAME HOST_GROUPNAME HOST_UID HOST_GID 


# Source the distro-specific config_docker_XXX.sh
DISTRO=${__DISTRO:-$DEFAULT_DISTRO}
DOCKER_CONFIG_FILE=${SCRIPT_DIR}/docker/config_docker_${DISTRO}.sh
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
