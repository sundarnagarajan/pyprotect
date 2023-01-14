
- All '.sh' files REQUIRE bash. The scripts use bash-specific features,
  such as associative arrays

config.sh and Dockerfiles for different Linux distributions:
__________________________________________________________________________
Distribution        config.sh           Dockerfile(s)
__________________________________________________________________________
Ubuntu jammy 22.04  config.sh.ubuntu    Dockerfile.ubuntu
Alpine 3.15         config.sh.alpine    Dockerfile.alpine (PY2, PY3, PYPY3)
                                        Dockerfile.alpine.pypy2 (PYPY2)
__________________________________________________________________________
To use a specific distribution in Docker:
    - COPY respective config.sh file to 'config.sh'
    - Run host_docker_build.sh to build Docker image(s)

- PYTHON_VERSION tags: in TAG_PYVER associative array in config.sh
    - PY3   : python3
    - PY2   : python2
    - PYPY3 : pypy3
    - PYPY2 : pypy

- Scripts with names starting with 'host_' require docker command
- Scripts with names starting with 'root_' need to be run as root
- Scripts with names endiing in '_in_docker.sh' need to be run in
  a docker container

__________________________________________________________________________
Script                                  Needs       Only in     Needs
Name                                    root        Docker      docker
__________________________________________________________________________
check_sha256.sh                         NO          NO          No
check_sig.sh                            NO          NO          No
clean_build.sh                          NO          NO          No
clean.sh                                NO          NO          No
cythonize.sh                            NO          NO          No
docker_as.sh                            NO          NO          YES
gpg_sign.sh                             NO          NO          No
host_build_in_place.sh                  NO          NO          YES
host_docker_build.sh                    NO          NO          YES
host_test.sh                            NO          NO          YES
inplace_build.sh                        NO          NO          No
root_install_test_in_docker.sh          YES         YES         NO
run_func_tests.sh                       NO          NO          No
venv_test_install_inplace.sh            NO          YES         No
__________________________________________________________________________

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

gpg_sign.sh:
    - Signs files in signed_files.txt and creates signature.asc
    - Takes no arguments

host_build_in_place.sh:
    - Builds extensions in-place using inplace_build.sh
    - Takes one or more optional PYTHON_VERSION tags as arguments

host_docker_build.sh:
    - Builds docker image
    - Can specify additional build arguments - e.g. '--no-cache'
      using env var 'ADDL_ARGS':
        ADDL_ARGS='--no-cache' ./docker_build.sh

host_test.sh:
    - Runs tests inside Docker container
    - Takes one or more optional PYTHON_VERSION tags as arguments

inplace_build.sh:
    - Takes one or more optional PYTHON_VERSION tags as arguments
    - Builds pyprotect extension in place using
      PYTHON_VERSION setup.py build_ext --inplace

root_install_test_in_docker.sh:
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

run_func_tests.sh:
    - Takes one or more optional PYTHON_VERSION tags as arguments
    - Runs tests

venv_test_install_inplace.sh:
    - Can only be run inside a Docker container
    - Takes one or more optional PYTHON_VERSION tags as arguments
    - Expects to be run as non-root user, but
        - Can run as root

    - For PYTHON_VERSION tag:
        - Creates  a virtualenv with that PYTHON_VERSION
            - Install and test using 'PYTHON_VERSION -m pip install .'
            - Uninstall using 'PYTHON_VERSION -m pip uninstall -y pyprotect'
            - Install and test using 'PYTHON_VERSION setup.py install'
            - Uninstall using 'PYTHON_VERSION -m pip uninstall -y pyprotect'
        - Builds and tests inplace using cythonize.sh and inplace_build.sh 
