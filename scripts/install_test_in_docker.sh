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

# Disable pip warnings that are irrelevant here
export PIP_DISABLE_PIP_VERSION_CHECK=1
export PIP_NO_PYTHON_VERSION_WARNING=1
export PIP_ROOT_USER_ACTION=ignore

function hide_output_unless_error() {
    local ret=0
    local out=$($@ 2>&1 || ret=$?)
    [[ $ret -ne 0 ]] && {
        >&2 echo "$out"
        return $ret
    }
    return 0
}


function uninstall() {
    echo "---------- Uninstalling using pip2 ----------------------------"
    hide_output_unless_error pip2 uninstall -y  pyprotect
    echo "---------- Uninstalling using pip3 ----------------------------"
    hide_output_unless_error pip3 uninstall -y  pyprotect
    echo "---------- Uninstalling using pypy3 -m pip --------------------"
    hide_output_unless_error pypy3 -m pip uninstall -y  pyprotect
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
echo "---------- Installing using pip2 ------------------------------"
hide_output_unless_error pip2 install .
echo "---------- Installing using pip3 ------------------------------"
hide_output_unless_error pip3 install . 
echo "---------- Installing using pypy3 -m pip ----------------------"
hide_output_unless_error pypy3 -m pip install .
${DOCKER_MOUNTPOINT}/scripts/clean_build.sh
run_tests

cd ${DOCKER_MOUNTPOINT}
uninstall
${DOCKER_MOUNTPOINT}/scripts/clean_build.sh
echo "---------- Installing using python2 setup.py ------------------"
hide_output_unless_error python2 setup.py install
echo "---------- Installing using python3 setup.py ------------------"
hide_output_unless_error python3 setup.py install
echo "---------- Installing using pypy3 setup.py --------------------"
hide_output_unless_error pypy3 setup.py install
${DOCKER_MOUNTPOINT}/scripts/clean_build.sh
run_tests

