#!/bin/bash
# --------------------------------------------------------------------
# DO NOT CHANGE ANYTHING in this file
# Needs generic_bash_functions.sh sourced before this file is sourced
#
# vars that define filesystem location
# Allow top-level source directory to be relocated
# Allow first-level sub-directory ('r') to change
# WITHOUT changing ANY script or config
#
# --------------------------------------------------------------------
SCRIPT_DIR=$(readlink -f $(dirname $BASH_SOURCE))


# config vars are made read-only, so they are guarded by __CONFIG_DIRS_SOURCED
var_declared __CONFIG_DIRS_SOURCED && return
var_empty __CONFIG_DIRS_SOURCED || return

# Make sure these variables are set ONLY in this script and not from env
for v in \
    SOURCE_TOPLEVEL_DIR \
    TOPLEVEL_SUBDIR \
    CONFIG_DIR \
    SCRIPTS_DIR \
    DOCKER_DISTROS_DIR \
    DOCKER_MANYLINUX_DIR \
    FEATURES_DIR 
do
    unset $v
done

# SOURCE_TOPLEVEL_DIR is top level dir of source (containing setup.py)
SOURCE_TOPLEVEL_DIR=$(readlink -f $(dirname "${BASH_SOURCE}")/../..)
# TOPLEVEL_SUBDIR is the directory containing directories for scripts,
# config, Dockerfiles etc
TOPLEVEL_SUBDIR=$(readlink -f $(dirname "${BASH_SOURCE}")/..)
TOPLEVEL_SUBDIR=$(basename "${TOPLEVEL_SUBDIR}")

# --------------------------------------------------------------------
# Things that depend on layout UNDER TOPLEVEL_SUBDIR
# ONLY these should be used within scripts
CONFIG_DIR=config
SCRIPTS_DIR=scripts
DOCKER_DISTROS_DIR=docker_distros
DOCKER_MANYLINUX_DIR=docker_manylinux
FEATURES_DIR=features
# --------------------------------------------------------------------

# Validate
# This recipe assumes 'setup.py' at a fairly low level
[[ -f "${SOURCE_TOPLEVEL_DIR}"/setup.py ]] || {
    >&2 red "setup.py not found in SOURCE_TOPLEVEL_DIR: ${SOURCE_TOPLEVEL_DIR}"
    errors=1
}
[[ -d "${SOURCE_TOPLEVEL_DIR}/${TOPLEVEL_SUBDIR}" ]] || {
    >&2 red "TOPLEVEL_SUBDIR not a directory: ${SOURCE_TOPLEVEL_DIR}/${TOPLEVEL_SUBDIR}"
    errors=1
}

# Make these relative paths under SOURCE_TOPLEVEL_DIR
# Will work when source is relocated using relocate_source
CONFIG_DIR=${TOPLEVEL_SUBDIR}/$(basename "${CONFIG_DIR}")
SCRIPTS_DIR=${TOPLEVEL_SUBDIR}/$(basename "${SCRIPTS_DIR}")
DOCKER_DISTROS_DIR=${TOPLEVEL_SUBDIR}/$(basename "${DOCKER_DISTROS_DIR}")
DOCKER_MANYLINUX_DIR=${TOPLEVEL_SUBDIR}/$(basename "${DOCKER_MANYLINUX_DIR}")
FEATURES_DIR=${TOPLEVEL_SUBDIR}/$(basename "${FEATURES_DIR}")

for v in CONFIG_DIR SCRIPTS_DIR DOCKER_DISTROS_DIR DOCKER_MANYLINUX_DIR FEATURES_DIR
do
    var_empty_not_spaces $v && {
        >&2 red "Variable not set (unexpected): $v"
        errors=1
        continue
    }
    [[ -d "${SOURCE_TOPLEVEL_DIR}/${!v}" ]] || {
        >&2 red "${v} not a directory: ${SOURCE_TOPLEVEL_DIR}/${!v}"
        errors=1
    }
done

# Make these read-only
readonly \
    SOURCE_TOPLEVEL_DIR \
    TOPLEVEL_SUBDIR \
    CONFIG_DIR \
    SCRIPTS_DIR \
    DOCKER_DISTROS_DIR \
    DOCKER_MANYLINUX_DIR \
    FEATURES_DIR 
# ------------------------------------------------------------------------

__CONFIG_DIRS_SOURCED=yes
readonly __CONFIG_DIRS_SOURCED
