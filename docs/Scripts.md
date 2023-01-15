### This document is still a work in progress

### Overview
- All '.sh' files REQUIRE bash. The scripts use bash-specific features,  such as associative arrays
- The only files in ```scripts``` directory with project-specific definitions is ```config.sh*```

#### config.sh and Dockerfiles for different Linux distributions

| Distribution       | config.sh        | Dockerfile(s)                       |
|--------------------|------------------|-------------------------------------|
| Ubuntu jammy 22.04 | config.sh.ubuntu | Dockerfile.ubuntu                   |
| Alpine Linux 3.15  | config.sh.alpine | Dockerfile.alpine (PY2, PY3, PYPY3) |

To use a specific distribution in Docker:
- COPY respective config.sh file to 'config.sh'
- Run host_docker_build.sh to build Docker image(s)

#### Running the scripts
- Scripts with names starting with 'host_' require docker command
- Scripts with names starting with 'root_' need to be run as root
- Scripts with names endiing in '\_in\_docker.sh' need to be run in  a docker container

| Script name                    | Needs root | Only in Docker<BR>container | Needs docker<BR>command |
|--------------------------------|------------|-----------------------------|-------------------------|
| check_sha256.sh                | NO         | NO                          | NO                      |
| check_sig.sh                   | NO         | NO                          | NO                      |
| clean_build.sh                 | NO         | NO                          | NO                      |
| clean.sh                       | NO         | NO                          | NO                      |
| cythonize.sh                   | NO         | NO                          | NO                      |
| docker_as.sh                   | NO         | NO                          | YES                     |
| gpg_sign.sh                    | NO         | NO                          | NO                      |
| host_build_in_place.sh         | NO         | NO                          | YES                     |
| host_docker_build.sh           | NO         | NO                          | YES                     |
| host_test.sh                   | NO         | NO                          | YES                     |
| inplace_build.sh               | NO         | NO                          | NO                      |
| root_install_test_in_docker.sh | YES        | YES                         | NO                      |
| run_func_tests.sh              | NO         | NO                          | NO                      |
| update_manifest.sh             | NO         | NO                          | NO                      |
| update_signed_files.sh         | NO         | NO                          | NO                      |
| venv_test_install_inplace.sh   | NO         | YES                         | NO                      |

- PYTHON_VERSION tags: in TAG_PYVER associative array in config.sh
    - PY3   : python3
    - PY2   : python2
    - PYPY3 : pypy3
    - PYPY2 : pypy


##### check_sha256.sh
- Checks sha256sums in signature.asc
- Takes no arguments

##### check_sig.sh
- Checks signature.asc
- Takes no arguments

##### clean_build.sh
- Cleans up build files
- Takes no arguments

##### clean.sh
- Cleans up build files - calling clean_build.sh
- ALSO removes pyprotect/protected.c and pyprotect/*.so
- Takes no arguments

##### cythonize.sh
- Creates protected.c if it is missing or outdated

##### docker_as.sh
Run ```docker_as.sh --help```
```
docker_as.sh [-|--help] [-p <PYTHON_VERSION_TAG>] [-u DOCKER_USER
    -h | --help              : Show this help and exit
    -p <PYTHON_VERSION_TAG>  : Use docker image for PYTHON_VERSION_TAG
        PYTHON_VERSION_TAG   : Key of TAG_PYVER in config.sh
    -u <DOCKER_USER>
        DOCKER_USER          : <username | uid | uid:gid>
```
##### gpg_sign.sh
- Signs files in signed_files.txt and creates signature.asc
- Takes no arguments

##### host_build_in_place.sh
- Builds extensions in-place using inplace_build.sh
- Takes one or more optional PYTHON_VERSION tags as arguments

##### host_docker_build.sh
- Builds docker image
- Can specify additional build arguments to docker build as arguments
- Some cases where this can be useful: 
    - Use '--no-cache' to discard old cached intermediate layers   

##### host_test.sh
- Runs tests inside Docker container
- Takes one or more optional PYTHON_VERSION tags as arguments

##### inplace_build.sh:
- Takes one or more optional PYTHON_VERSION tags as arguments
- Builds pyprotect extension in place using ```PYTHON_VERSION setup.py build_ext --inplace```

##### root_install_test_in_docker.sh
- Can only be run inside a Docker container
- Must be run as root inside Docker container
- Takes one or more optional PYTHON_VERSION tags as arguments
- Runs various tests inside Docker container:
    - For PYTHON_VERSION tag:
        - Install and test using 'PYTHON_VERSION -m pip install .'
        - Uninstall using 'PYTHON_VERSION -m pip uninstall -y pyprotect'
        - Install and test using 'PYTHON_VERSION setup.py install'
        - Uninstall using 'PYTHON_VERSION -m pip uninstall -y pyprotect'
- Calls venv_test_install_inplace.sh to run virtualenv and in-place tests as non-root user

##### run_func_tests.sh
- Takes one or more optional PYTHON_VERSION tags as arguments
- Runs tests

##### update_manifest.sh
- Updates MANIFEST.in
- Takes no arguments

##### update_signed_files.sh
- Updates signed_files.txt
- Takes no arguments

##### venv_test_install_inplace.sh
- Can only be run inside a Docker container
- Takes one or more optional PYTHON_VERSION tags as arguments
- Expects to be run as non-root user, but can run as root

- For PYTHON_VERSION tag:
    - Creates  a virtualenv with that PYTHON_VERSION
        - Install and test using 'PYTHON_VERSION -m pip install .'
        - Uninstall using 'PYTHON_VERSION -m pip uninstall -y pyprotect'
        - Install and test using 'PYTHON_VERSION setup.py install'
        - Uninstall using 'PYTHON_VERSION -m pip uninstall -y pyprotect'
    - Builds and tests inplace using cythonize.sh and inplace_build.sh 
