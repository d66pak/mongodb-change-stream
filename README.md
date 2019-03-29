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
* Note that you might need to create a new repository in ECR (Amazon Elastic Container Registry) for the first time.
* Here's the command to create repository in ECR
  ```bash
  aws ecr create-repository --repository-name 2ki/mongo-change-stream --profile default
  ```
* Here's the command to create an image:
  ```bash
  packer build -var 'aws_region=ap-southeast-2' -var 'timezone=Australia/ACT' -var 'aws_account_id=111111111111' change_stream.json
  ```
* The image will be build and pushed to Amazon Elastic Container registry.
* Packer config [change_stream.json](./packer/change_stream.json) runs the Ansible provisioner [provision.yml](./packer/provision.yml). Both of them are quiet straight forward to understand with basic Packer and Ansible knowledge.

## How to test your changes locally?
* Create an docker image:
    ```bash
    packer build -var 'aws_region=ap-southeast-2' -var 'timezone=Australia/ACT' change_stream_local.json
    ```
* Once the image is created it will be tagged as 'latest'.
* Run the image using [change_stream_start.sh](./packer/change_stream_start.sh) script.
* Example:
    ```bash
    ./change_stream_start.sh 2ki/mongo-change-stream
    ```
* You can open a bash shell on the running container.
    ```bash
    docker exec -it $(docker ps --filter "ancestor=2ki/mongo-change-stream" -q) bash
    ```
* If you want to stop the container use below command.
   ```bash
   docker stop $(docker ps --filter "ancestor=2ki/mongo-change-stream" -q)
   ```
* Few useful Docker commands:
  * ```docker images``` : List all images.
  * ```docker ps``` : List running containers.
  * ```docker ps -a``` : List all containers including stopped.
  * ```docker rm $(docker ps -a -q)``` : Remove all containers.
  * ```docker rmi $(docker images -q)``` : Remove all images.

## List of environment variables to start container
1. AWS_DEFAULT_REGION
   * AWS region
1. MONGODB_URI
    * MongoDB connection URI.

