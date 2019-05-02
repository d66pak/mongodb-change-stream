#!/usr/bin/env bash

# NOTE: Pass docker image id as parameter
# USAGE:
# ./change_stream_start.sh 2ki/mongo-change-stream

AWS_DEFAULT_REGION="ap-southeast-2"

LOG_LEVEL="DEBUG"
MONGODB_URI="mongodb+srv://<dns-server-url>/<db>?authSource=<auth_db>"
MONGODB_USERNAME="<username>"
MONGODB_PASSWORD="<password>"
MONGODB_DATABASE="<db>"
MONGODB_COLLECTION="<collection>"

# Use:
# -d option to run in background
# --rm option to remove the container after its stopped
docker run \
    -e "AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}" \
    -e "LOG_LEVEL=${LOG_LEVEL}" \
    -e "MONGODB_URI=${MONGODB_URI}" \
    -e "MONGODB_USERNAME=${MONGODB_USERNAME}" \
    -e "MONGODB_PASSWORD=${MONGODB_PASSWORD}" \
    -e "MONGODB_DATABASE=${MONGODB_DATABASE}" \
    -e "MONGODB_COLLECTION=${MONGODB_COLLECTION}" \
    ${1}
