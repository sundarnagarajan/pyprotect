
- All '.sh' files REQUIRE bash
Following scripts can run ONLY inside a docker container:
    install_test_in_docker.sh
    venv_test_install_inplace.sh
- Following scripts USE Docker container(s) and MUST be run on the host:
    build_in_place_in_docker.sh
    test_in_docker.sh
- Remaining scripts CAN run inside Docker containers or on the host

- Python versions:
    - python3 - denoted with 'tag' PY3
    - python2 - denoted with 'tag' PY2
    - pypy3 - denoted with 'tag' PYPY3
    - pypy - denoted with 'tag' PYPY2

build_in_place_in_docker.sh:
    - Builds extensions in-place using inplace_build.sh
    - Builds for PY3 PY2 PYPY3 PYPY2
    - Takes no arguments

check_sha256.sh: Checks sha256sums in signature.asc. Takes no arguments

check_sig.sh: Checks signature.asc. Takes no arguments

clean_build.sh: Cleans up build files. Takes no arguments

clean.sh:
    - Cleans up build files - calling clean_build.sh
    - ALSO removes pyprotect/protected.c and pyprotect/*.so
    - Takes no arguments

cythonize.sh: Creates protected.c if it is missing or outdated

docker_as.sh: Run docker_as.sh --help
    -h | --help        : Show this help and exit
    -p <PY2 | PY3>     : Use docker image for PY2 | PY3
    -u <DOCKER_USER>
        DOCKER_USER: <username | uid | uid:gid>

docker_build.sh:
    - Builds docker image
    - Can specify additional build arguments - e.g. '--no-cache'
      using env var 'ADDL_ARGS':
        ADDL_ARGS='--no-cache' ./docker_build.sh

gpg_sign.sh:
    - Signs files in signed_files.txt and creates signature.asc
    - Takes no arguments

inplace_build.sh:
    - Builds pyprotect extension in place using
      PYTHON_VERSION setup.py build_ext --inplace
    - REQUIRES one argument: python executable basename
    - Must be python2 | python3 | pypy3 | pypy

install_test_in_docker.sh:
    - Can only be run inside a Docker container
    - Must be run as root inside Docker container
    - Runs various tests inside Docker container:
        - For each tag: PY3, PY2, PYPY3, PYPY2
            - Install and test using 'PYTHON_VERSION -m pip install .'
            - Uninstall using 'PYTHON_VERSION -m pip uninstall -y pyprotect'
            - Install and test using 'PYTHON_VERSION setup.py install'
            - Uninstall using 'PYTHON_VERSION -m pip uninstall -y pyprotect'
    - Calls venv_test_install_inplace.sh to run virtualenv and in-place
      tests as non-root user

test_in_docker.sh:
    - Runs tests inside Docker container
    - Accepts one optional argument: python tag: PY3 | PY2 | PYPY3 | PYPY2
    - If no python tag provided, runs tests for PY3 | PY2 | PYPY3 | PYPY2

venv_test_install_inplace.sh:
    - Accepts no arguments
    - Expects to be run inside Docker container as non-root user, but
        - Can run as root inside Docker container
        - Can run outside Docker container

    - For each tag: PY3, PY2, PYPY3, PYPY2
        - Creates  a virtualenv with that PYTHON_VERSION
            - Install and test using 'PYTHON_VERSION -m pip install .'
            - Uninstall using 'PYTHON_VERSION -m pip uninstall -y pyprotect'
            - Install and test using 'PYTHON_VERSION setup.py install'
            - Uninstall using 'PYTHON_VERSION -m pip uninstall -y pyprotect'
        - Builds and tests inplace using cythonize.sh and inplace_build.sh 
