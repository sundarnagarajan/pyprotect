#!/bin/bash
# Config for testing, uploading using manylinux images

# Maps "tags" to refer to docker images
# Only "tags" that have docker images defined will be considered
# For running tests, and only if corresponding docker image exists
declare -A MANYLINUX_TAG_IMAGE=(
    ["manylinux1"]=manylinux1:latest
    ["musllinux"]=musllinux:latest
    ["manylinux_2_28"]=manylinux_2_28:latest
)

# Maps "tags to Dockerfile names
# MANYLINUX_TAG_DOCKERFILE is only used in host_manylinux_docker_build.sh
# Only image names with existing Docker files will be built
declare -A MANYLINUX_TAG_DOCKERFILE=(
    ["manylinux1"]=Dockerfile.manylinux1
    ["musllinux"]=Dockerfile.musllinux
    ["manylinux_2_28"]=Dockerfile.manylinux_2_28
)

# Manylinux images are used only for PY3 and PYPY3
# For each of PY3 and PYPY3:
#   MIN_VER       : Min major.minor version to consider (inclusive)
#   MAX_VER_EXCL  : Max major.minor version to consider (EXCLUSIVE)
# i.e. check is: MIN_VER <= python_ver < MAX_VER_EXCL
#
# If MIN_VER is not set, check is python_ver < MAX_VER_EXCL
# If MAX_VER_EXCL is not set, check is MIN_VER <= python_ver
# If neither MIN_VER not MAX_VER_EXCL are set, check always succeeds
#
PY3_MIN_VER=3.0
PY3_MAX_VER_EXCL=3.11
PYPY3_MIN_VER=3.0
PYPY3_MAX_VER_EXCL=3.11

