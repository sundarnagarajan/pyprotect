#!/bin/bash
#
set -e -u -o pipefail
PROG_DIR=$(readlink -e $(dirname $0))
source "$PROG_DIR"/common_functions.sh


# Check that required variables are set
for v in HOST_USERNAME HOST_GROUPNAME HOST_UID HOST_GID
do
    declare -n check=${v}
    [[ ${check+x} ]] || {
        >&2 red "$(basename ${BASH_SOURCE}): Required variable not set in config.sh: ${v}"
        exit 1
    }
done
[[ -n $(declare -p DOCKERFILE_IMAGE 2>/dev/null) ]] || {
    >&2 red "$(basename ${BASH_SOURCE}): Required variable not set in config.sh: DOCKERFILE_IMAGE" 
    exit 1
}

cd "${SOURCE_TOPLEVEL_DIR}"/${DOCKER_DISTROS_DIR}

CYTHON_DOCKER_BUILD_REQUIRED=1
CYTHON_IN_IMAGE=""

for k in ${!DOCKERFILE_IMAGE[@]}
do
    IMAGE_NAME=${DOCKERFILE_IMAGE[$k]}
    [[ ${IMAGE_NAME}+x == "x" ]] && {
        >&2 red "$(basename ${BASH_SOURCE}): Image name not found for Docker file: $k"
        exit 1
    }
    >&2 blue "Building $IMAGE_NAME from $k"

    docker build \
        --build-arg HOST_USERNAME=$HOST_USERNAME \
        --build-arg HOST_GROUPNAME=$HOST_GROUPNAME \
        --build-arg HOST_UID=$HOST_UID \
        --build-arg HOST_GID=$HOST_GID \
        --build-arg HOME_DIR=/home \
        --build-arg MODULE_MOUNT_DIR=/${PY_MODULE} \
        -t $IMAGE_NAME -f $k $@ .

    # Track requirement to build separate image for cython
    [[ -n "${EXTENSION_NAME:-}" && "${CYTHONIZE_REQUIRED:-}" = "yes" ]] && {
        [[ "${CYTHON_DOCKER_FILE:-}" = "$k" ]] && {
            CYTHON_DOCKER_BUILD_REQUIRED=0
            CYTHON_IN_IMAGE=$IMAGE_NAME
        }
    }
done

# Build separate image for cython if required

[[ "$CYTHON_DOCKER_BUILD_REQUIRED" -eq 0 ]] && {
    [[ -z "${EXTENSION_NAME:-}" ]] && {
        >&2 echo "No C-extension: EXTENSION_NAME not set"
    } || [[ "${CYTHONIZE_REQUIRED:-}" != "yes" ]] && {
        >&2 echo "C-extension does not require cython"
    }
    >&2 blue "Cython is in Docker image $CYTHON_IN_IMAGE"
    exit 0
}

# Need separate image for Cython

[[ -n "${EXTENSION_NAME:-}" && "${CYTHONIZE_REQUIRED:-}" = "yes" ]] && {
    [[ -n "${CYTHON_DOCKER_FILE:-}" ]] && {
        [[ -n "${CYTHON3_DOCKER_IMAGE:-}" ]] && {
            docker build \
                --build-arg HOST_USERNAME=$HOST_USERNAME \
                --build-arg HOST_GROUPNAME=$HOST_GROUPNAME \
                --build-arg HOST_UID=$HOST_UID \
                --build-arg HOST_GID=$HOST_GID \
                --build-arg HOME_DIR=/home \
                --build-arg MODULE_MOUNT_DIR=/${PY_MODULE} \
                -t $CYTHON3_DOCKER_IMAGE -f $CYTHON_DOCKER_FILE $@ .
        } || {
            >&2 red "$(basename ${BASH_SOURCE}): CYTHON3_DOCKER_IMAGE not set in $(basename ${DOCKER_CONFIG_FILE})"
        }
    } || {
        >&2 red "$(basename ${BASH_SOURCE}): CYTHON3_DOCKER_FILE not set in $(basename ${DOCKER_CONFIG_FILE})"
    }
}


