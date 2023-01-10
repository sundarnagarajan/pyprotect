#!/bin/bash
# Fully reusable - changing only config.sh
#
set -eu -o pipefail
PROG_DIR=$(readlink -e $(dirname $0))
SCRIPT_NAME=$(basename $0)
source "$PROG_DIR"/../scripts/config.sh
[[ $(id -u) -ne 0 ]] && {
    >&2 echo "${SCRIPT_NAME}: Run as root"
    exit 1
}
grep -q '/init\.scope$' /proc/1/cgroup && {
    >&2 echo "${SCRIPT_NAME}: Not running in docker"
    exit 1
}

function uninstall() {
    pip2 uninstall -y pyprotect
    pip3 uninstall -y pyprotect
    pypy3 -m pip uninstall -y pyprotect
}

function run_tests() {
    rm -rf /root/tests
    cp -a /home/tests /root/ 
    cd /root
    /root/tests/run_func_tests.sh
}

cd ${DOCKER_MOUNTPOINT}
${DOCKER_MOUNTPOINT}/scripts/cythonize.sh

cd ${DOCKER_MOUNTPOINT}
uninstall
${DOCKER_MOUNTPOINT}/scripts/clean_build.sh
pip2 install .
pip3 install . 
pypy3 -m pip install .
${DOCKER_MOUNTPOINT}/scripts/clean_build.sh
run_tests

cd ${DOCKER_MOUNTPOINT}
uninstall
${DOCKER_MOUNTPOINT}/scripts/clean_build.sh
python2 setup.py install
python3 setup.py install
pypy3 setup.py install
${DOCKER_MOUNTPOINT}/scripts/clean_build.sh
run_tests

