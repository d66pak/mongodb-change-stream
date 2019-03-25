#!/usr/bin/env bash

##
# This script setups the execution environment
##

ABSOLUTE=$(realpath $0)
VIRTUAL_ENV_DIR=$(dirname ${ABSOLUTE})/virtual_env

command -v virtualenv > /dev/null 2>&1 || { echo "I require 'virtualenv' but it's not installed.  Aborting." >&2; exit 1; }
command -v pip > /dev/null 2>&1 || { echo "I require 'pip' but it's not installed.  Aborting." >&2; exit 1; }

echo "Creating virtual environment at location: ${VIRTUAL_ENV_DIR}"
virtualenv -p python3 ${VIRTUAL_ENV_DIR}

if [ $? -ne 0 ]; then
    echo "Failed to create virtual env. Exiting..."
    exit 1
fi

# VIRTUAL_ENV variable will be set if virtual env is activated.
if [ -z $VIRTUAL_ENV ];
then
    echo "Loading python virtualenv..."
    source ${VIRTUAL_ENV_DIR}/bin/activate
fi

echo "Installing required packages..."
pip install --upgrade pip
pip install boto3
pip install ansible
pip install pymongo
pip install dnspython
