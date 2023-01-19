#!/bin/bash

COMMON_CONTAINER_NAME=py23_pypy3:alpine-3.15
# If $CYTHON_DOCKER_FILE is in DOCKERFILE_IMAGE, CYTHON3_DOCKER_IMAGE=
# is not required
CYTHON_DOCKER_FILE=Dockerfile.alpine
# CYTHON3_DOCKER_IMAGE=$COMMON_CONTAINER_NAME

# Can OVERRIDE CYTHON3_PROG_NAME from default in cconfig.sh
# E.g. On Fedora 37, python3-Cython package installs v0.29.32 as 'cython'
# E.g. in Alpine Linux 3.15, cython package installs v0.29.24 as 'cython'
# E.g. on Arch, cython3 package installs v3.0.0a11 as 'cython'
CYTHON3_PROG_NAME=cython

# Can selectively OVERRIDE python program executable basename for
# selected tags set in TAG_PYVER in config.sh
# E.g. on Fedora 37, default python3 is 3.11 and is not compatible
# with python3-Cython - need to install and use python3.10
# TAG_PYVER["PY3"]=python3.10

# TAG_IMAGE: maps PYTHON_VERSION tags to docker image names
declare -A TAG_IMAGE=(
    ["PY3"]=$COMMON_CONTAINER_NAME
    ["PY2"]=$COMMON_CONTAINER_NAME
    ["PYPY3"]=$COMMON_CONTAINER_NAME
    ["PYPY2"]=pypy2:alpine-3.15
)
# DOCKERFILE_IMAGE maps Docker file names to Docker image names
# Used (only) in docker_build.sh
declare -A DOCKERFILE_IMAGE=(
    [Dockerfile.alpine]=${TAG_IMAGE[PY3]}
    [Dockerfile.alpine.pypy2]=${TAG_IMAGE[PYPY2]}
)
