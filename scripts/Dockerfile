
FROM ubuntu:jammy
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

RUN echo "export PYTHONDONTWRITEBYTECODE=Y" >> /root/.bashrc

# Need build-essential python2-dev python3-dev and cython3 ONLY to BUILD module
# These are not required to install from PyPi or from bdist / wheel
# python3-numpy is used in a unit test test_62_matmul)
RUN apt-get install -y curl less unzip build-essential python2-dev python-setuptools python3-dev python3-setuptools cython3 python3-numpy python3-pip

# On Ubuntu / Debian cannot install python-pip and python3-pip
# together - they conflict among each other
# Install pip2 from https://bootstrap.pypa.io/get-pip.py
RUN curl -s https://raw.githubusercontent.com/pypa/get-pip/main/public/2.7/get-pip.py | python2

# Upgrade pip3 to 22.3.1 - v22.0.2+dfsg-1 has problems uninstalling packages !
# AttributeError: 'EggMetadata' object has no attribute 'isdir'
# Silence irrelevant warning about running pip as root user
RUN pip3 install -U "pip>=22.3.1" 2>/dev/null

# python2-setuptools-whl and python2-pip-whl are only needed to create
# PY2 virtualenv using virtualenv command
# RUN apt install -y python2-setuptools-whl python2-pip-whl

RUN rm -rf /var/lib/apt/lists
