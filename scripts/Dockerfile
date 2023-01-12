
FROM ubuntu:jammy

# Check required arg before doing extra works
ARG HOST_GID
ARG HOST_GROUPNAME
ARG HOST_UID
ARG HOST_USERNAME
ARG HOME_DIR
ARG PY3_WHEELS_DIR
ARG PYPY3_WHEELS_DIR

# ----------------------------------------------------------------------
# Common things to always do
# ----------------------------------------------------------------------
ENV DEBIAN_FRONTEND=noninteractive
RUN dpkg-reconfigure debconf --frontend=noninteractive
RUN apt-config dump | grep -we Recommends -e Suggests | sed s/1/0/ > /etc/apt/apt.conf.d/999no_recommend_suggests
# Next 3 lines are required for pydoc2 to show unicode data
ENV LANG=en_US.UTF-8
ENV LANGUAGE=$LANG
ENV LC_ALL=$LANG

RUN rm -rf /var/lib/apt/lists/*
RUN apt-get clean
RUN apt-get update
RUN apt-get install -y apt-utils locales 2>/dev/null
# Next 2 lines are required for pydoc2 to show unicode data
RUN locale-gen $LANG 2>/dev/null
RUN dpkg-reconfigure locales 2>/dev/null
RUN apt-get upgrade -y
RUN apt-get dist-upgrade -y
# ----------------------------------------------------------------------

ENV PIP_ROOT_USER_ACTION=ignore
RUN echo "export PYTHONDONTWRITEBYTECODE=Y" >> /root/.bashrc

# Need build-essential python2-dev python3-dev and cython3 ONLY to BUILD module
# These are not required to install from PyPi or from bdist / wheel
# python3-numpy is used in a unit (test test_62_matmul)
# python2-setuptools-whl and python2-pip-whl are only needed to create
# PY2 virtualenv using virtualenv command
RUN apt-get install -y curl less unzip build-essential python2-dev python-setuptools python3-dev python3-setuptools cython3 python3-numpy python3-pip python3-virtualenv python2-setuptools-whl python2-pip-whl

# Upgrade pip3 to 22.3.1 - v22.0.2+dfsg-1 has problems uninstalling packages !
# AttributeError: 'EggMetadata' object has no attribute 'isdir'
# Silence irrelevant warning about running pip as root user
RUN PIP_ROOT_USER_ACTION=ignore pip3 install -U "pip>=22.3.1" 2>/dev/null

# On Ubuntu / Debian cannot install python-pip and python3-pip
# together - they conflict among each other
# Install pip2 from https://bootstrap.pypa.io/get-pip.py
# Suppress stderr to hide irrelevant warning about Python2 EOL
RUN curl -s https://raw.githubusercontent.com/pypa/get-pip/main/public/2.7/get-pip.py | python2 2>/dev/null

# ----------------------------------------------------------------------
# Install pypy, pypy3 from PPA
RUN apt-get install -y apt-transport-https ca-certificates gnupg dirmngr curl less
WORKDIR /etc/apt/repo-keyrings
RUN curl -sL "http://keyserver.ubuntu.com/pks/lookup?op=get&search=0x2862D0785AFACD8C65B23DB0251104D968854915" | gpg --dearmor > pypy.gpg
WORKDIR /etc/apt/sources.list.d
RUN echo "deb [ arch=amd64 signed-by=/etc/apt/repo-keyrings/pypy.gpg ] https://ppa.launchpadcontent.net/pypy/ppa/ubuntu jammy main" > pypy.list
RUN apt-get update
RUN apt-get install -y pypy3 pypy3-dev pypy pypy-dev pypy-setuptools

# Rest is only to install numpy for pypy3

# cython >= 0.29.30 needed to BUILD numpy module for pypy3
# Cannot hide irrelevant warning during docker build!
RUN pypy3 -m pip install "cython >= 0.29.30" 2>/dev/null
WORKDIR /root
RUN rm -f *.whl
RUN >&2 echo "Building numpy wheel - takes 8-10 minutes"
RUN pypy3 -m pip wheel numpy
# Cannot hide irrelevant warning during docker build!
RUN pypy3 -m pip install numpy-*.whl 2>/dev/null

# Store the numpy wheel for reuse within a PYPY3 virtualenv
RUN mkdir -p $PYPY3_WHEELS_DIR
RUN mv numpy-*.whl "${PYPY3_WHEELS_DIR}"/
RUN chmod -R ugo+rX $PYPY3_WHEELS_DIR

RUN rm -f *.whl
# Cannot hide irrelevant warning during docker build!
RUN pypy3 -m pip uninstall -y cython 2>/dev/null

# Installing pip for pypy2 is fairly complex
# get-pip.py from https://bootstrap.pypa.io/pip/2.7/get-pip.py does not install with
# pypy because /usr/local/lib/pypy2.7/dist-packages/pip/_internal/operations/install/wheel.py
# assert on line 719 fails:
# assert os.path.exists(pyc_path)
#
# So need to copy pip and wheel from python2.7 dir and PATCH
# /usr/local/lib/pypy2.7/dist-packages/pip/_internal/operations/install/wheel.py
# to comment out line 719
# Although this works for the purpose of this Docker image -
# using pypy -m pip to install / uninstall pyprotect, there may be other
# untested effects
# See: https://github.com/pypa/pip/issues/8653#issuecomment-667124536
# Seems to be something to do with PEP 3147 and related differences
# between python 2.7 and pypy 2.7
#
WORKDIR /usr/local/lib/python2.7/dist-packages
RUN cp -a pip* wheel* /usr/local/lib/pypy2.7/dist-packages/
RUN sed -i '719,719 s/^/#/' /usr/local/lib/pypy2.7/dist-packages/pip/_internal/operations/install/wheel.py
# ----------------------------------------------------------------------


# Store PY3 numpy wheel in PY3_WHEELS_DIR for use in PY3 virtualenv
WORKDIR $PY3_WHEELS_DIR
RUN pip3 download numpy || pip3 wheel numpy
RUN chmod -R ugo+rX $PY3_WHEELS_DIR


# Create the non-root user
RUN addgroup --gid $HOST_GID $HOST_GROUPNAME
RUN adduser --home ${HOME_DIR} --no-create-home --uid $HOST_UID --gid $HOST_GID --disabled-password --gecos "$HOST_USERNAME" $HOST_USERNAME

ENV NORMAL_USER=$HOST_USERNAME
RUN rm -rf /var/lib/apt/lists
