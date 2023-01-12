#!/bin/bash
# In the future, PY2_DOCKER_IMAGE may be different
# As of now (ubuntu jammy) we have PY2, PY3, Cython3
# in the same container
PY3_DOCKER_IMAGE=python23:jammy
PY2_DOCKER_IMAGE=$PY3_DOCKER_IMAGE
PYPY3_DOCKER_IMAGE=$PY3_DOCKER_IMAGE
PYPY2_DOCKER_IMAGE=$PY3_DOCKER_IMAGE
CYTHON3_DOCKER_IMAGE=$PY3_DOCKER_IMAGE
DOCKER_MOUNTPOINT=/home
PY_MODULE=pyprotect
EXTENSION_NAME=protected

# Rest are automatic - do not need to be set / reviewed
HOST_USERNAME=$(id -un)
HOST_GROUPNAME=$(id -gn)
HOST_UID=$(id -u)
HOST_GID=$(id -g)
DOCKER_USER="${HOST_UID}:${HOST_GID}"
