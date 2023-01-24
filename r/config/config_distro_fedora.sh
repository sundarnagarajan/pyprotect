#!/bin/bash
COMMON_CONTAINER_NAME=py23_pypy23:fedora
# If $CYTHON_DOCKER_FILE is in DOCKERFILE_IMAGE, CYTHON3_DOCKER_IMAGE
# is not required
CYTHON_DOCKER_FILE=Dockerfile.fedora
# CYTHON3_DOCKER_IMAGE=$COMMON_CONTAINER_NAME

# Can OVERRIDE CYTHON3_PROG_NAME from default in cconfig.sh
# As of 20220122 we build cython 3.0.0a11 from github source
# CYTHON3_PROG_NAME=cython

# Can selectively OVERRIDE python program executable basename for
# selected tags set in TAG_PYVER in config.sh
# TAG_PYVER["PY3"]=python3.10

# TAG_IMAGE: maps PYTHON_VERSION tags to docker image names
declare -A TAG_IMAGE=(
    ["PY3"]=$COMMON_CONTAINER_NAME
    ["PY2"]=$COMMON_CONTAINER_NAME
    ["PYPY3"]=$COMMON_CONTAINER_NAME
    ["PYPY2"]=$COMMON_CONTAINER_NAME
)
# DOCKERFILE_IMAGE maps Docker file names to Docker image names
# Used (only) in docker_build.sh
declare -A DOCKERFILE_IMAGE=(
    [Dockerfile.fedora]=${TAG_IMAGE[PY3]}
)
