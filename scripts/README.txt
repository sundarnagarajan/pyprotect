
- All '.sh' files REQUIRE bash

- PYTHON_VERSION tags: in TAG_PYVER associative array in config.sh
    - PY3   : python3
    - PY2   : python2
    - PYPY3 : pypy3
    - PYPY2 : pypy

__________________________________________________________________________
Script                              root        Docker      Host
__________________________________________________________________________
build_in_place_in_docker.sh         Allowed     NO          Required
check_sha256.sh                     Allowed     Allowed     Allowed
check_sig.sh                        Allowed     Allowed     Allowed
clean_build.sh                      Allowed     Allowed     Allowed
clean.sh                            Allowed     Allowed     Allowed
cythonize.sh                        Allowed     Allowed     Allowed
docker_as.sh                        Allowed     NO          Required
docker_build.sh                     Allowed     NO          Required
gpg_sign.sh                         Allowed     Allowed     Allowed
inplace_build.sh                    Allowed     Allowed     Allowed
install_test_in_docker.sh           Required    NO          Required
run_func_tests.sh                   Allowed     Allowed     Allowed
test_in_docker.sh                   Allowed     NO          Required
venv_test_install_inplace.sh        Allowed     Allowed     Allowed
__________________________________________________________________________


build_in_place_in_docker.sh:
    - Builds extensions in-place using inplace_build.sh
    - Takes one or more optional PYTHON_VERSION tags as arguments

check_sha256.sh: Checks sha256sums in signature.asc. Takes no arguments

check_sig.sh: Checks signature.asc. Takes no arguments

clean_build.sh: Cleans up build files. Takes no arguments

clean.sh:
    - Cleans up build files - calling clean_build.sh
    - ALSO removes pyprotect/protected.c and pyprotect/*.so
    - Takes no arguments

cythonize.sh: Creates protected.c if it is missing or outdated

docker_as.sh: Run docker_as.sh --help
    docker_as.sh [-|--help] [-p <PYTHON_VERSION_TAG>] [-u DOCKER_USER
        -h | --help              : Show this help and exit
        -p <PYTHON_VERSION_TAG>  : Use docker image for PYTHON_VERSION_TAG
            PYTHON_VERSION_TAG   : Key of TAG_PYVER in config.sh
        -u <DOCKER_USER>
            DOCKER_USER          : <username | uid | uid:gid>

docker_build.sh:
    - Builds docker image
    - Can specify additional build arguments - e.g. '--no-cache'
      using env var 'ADDL_ARGS':
        ADDL_ARGS='--no-cache' ./docker_build.sh

gpg_sign.sh:
    - Signs files in signed_files.txt and creates signature.asc
    - Takes no arguments

inplace_build.sh:
    - Takes one or more optional PYTHON_VERSION tags as arguments
    - Builds pyprotect extension in place using
      PYTHON_VERSION setup.py build_ext --inplace

install_test_in_docker.sh:
    - Can only be run inside a Docker container
    - Must be run as root inside Docker container
    - Takes one or more optional PYTHON_VERSION tags as arguments
    - Runs various tests inside Docker container:
        - For PYTHON_VERSION tag:
            - Install and test using 'PYTHON_VERSION -m pip install .'
            - Uninstall using 'PYTHON_VERSION -m pip uninstall -y pyprotect'
            - Install and test using 'PYTHON_VERSION setup.py install'
            - Uninstall using 'PYTHON_VERSION -m pip uninstall -y pyprotect'
    - Calls venv_test_install_inplace.sh to run virtualenv and in-place
      tests as non-root user

test_in_docker.sh:
    - Runs tests inside Docker container
    - Takes one or more optional PYTHON_VERSION tags as arguments

venv_test_install_inplace.sh:
    - Takes one or more optional PYTHON_VERSION tags as arguments
    - Expects to be run inside Docker container as non-root user, but
        - Can run as root inside Docker container
        - Can run outside Docker container

    - For PYTHON_VERSION tag:
        - Creates  a virtualenv with that PYTHON_VERSION
            - Install and test using 'PYTHON_VERSION -m pip install .'
            - Uninstall using 'PYTHON_VERSION -m pip uninstall -y pyprotect'
            - Install and test using 'PYTHON_VERSION setup.py install'
            - Uninstall using 'PYTHON_VERSION -m pip uninstall -y pyprotect'
        - Builds and tests inplace using cythonize.sh and inplace_build.sh 
