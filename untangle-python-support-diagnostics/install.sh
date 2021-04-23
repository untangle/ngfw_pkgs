#!/bin/sh

SOURCE_DIRECTORY="$( cd "$( dirname "$0" )" && pwd )"
PYTHON=$(head -1 ${SOURCE_DIRECTORY}/bin/support_diagnostics | cut -d' ' -f2)
PYTHON_DIR=$(find /usr/lib -maxdepth 1 -name $PYTHON)

# Ensure target exists
TARGET_DIR=
if [ -d /etc/untangle ]; then
    TARGET_DIR=${PYTHON_DIR}/dist-packages
else
    TARGET_DIR=${PYTHON_DIR}/site-packages
fi

find ${TARGET_DIR} -regex '^.*\(__pycache__\|\.py[co]\)$' | xargs rm -rf

cp -a ${SOURCE_DIRECTORY}/bin/* /usr/bin
mkdir -p ${TARGET_DIR}
cp -a ${SOURCE_DIRECTORY}/support_diagnostics ${TARGET_DIR}
