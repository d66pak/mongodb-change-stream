# MongoDB (Change Stream) Watcher
* MongoDB watcher uses change streams introduced in MongoDB v3.6 to track changes.
* After reading the records from change stream, they are written to AWS Kinesis stream(s).
* This project uses [packer](https://www.packer.io) to build a Ubuntu docker image and push it to Amazon Elastic Container registry.

## Stateless
* Process state like last read MongoDB record is stored in DynamoDB.
* This allows the container to be restarted without loosing and state or missing MongoDB records.

## Container support
* This implementation runs as a Docker image in AWS Fargate/ECS.
* All the required parameters are passed as environment variables to running image.
* Passwords are stored in AWS SSM.
* [test_docker.sh](./test_docker.sh) script can be used to test docker image.

## Creating container image
* Packer and Ansible are used to build Docker image.

* Here's the command to create an image:
  ​

