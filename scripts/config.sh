#!/bin/bash
# In the future, PY2_DOCKER_IMAGE may be different
# As of now (ubuntu jammy) we have PY2, PY3, Cython3
# in the same container
PY3_DOCKER_IMAGE=python23:jammy
PY2_DOCKER_IMAGE=$PY3_DOCKER_IMAGE
PYPY3_DOCKER_IMAGE=$PY3_DOCKER_IMAGE
CYTHON3_DOCKER_IMAGE=$PY3_DOCKER_IMAGE
DOCKER_MOUNTPOINT=/home
PY_MODULE=pyprotect
EXTENSION_NAME=protected
