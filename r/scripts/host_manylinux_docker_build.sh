#!/bin/bash
set -e -u -o pipefail
PROG_DIR=$(readlink -e $(dirname $0))
source "$PROG_DIR"/common_functions.sh
source "$PROG_DIR"/config_manylinux_source_validate.sh


cd "${SOURCE_TOPLEVEL_DIR}"/${DOCKER_MANYLINUX_DIR}


for tag in "${!MANYLINUX_TAG_IMAGE[@]}"
do
    [[ ${MANYLINUX_TAG_DOCKERFILE["$tag"]+_} ]] && {
        img=${MANYLINUX_TAG_IMAGE["$tag"]}
        dk_file=${MANYLINUX_TAG_DOCKERFILE["$tag"]}
    docker build --build-arg MANYLINUX_IMAGE=$tag  $@ -t $img -f $dk_file .
    >&2 blue "Built image $img from $dk_file"
    } || {
        >&2 blue "Ignoring tag without Dockerfile defined: $tag"
        continue
    }
done
