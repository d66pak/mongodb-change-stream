# MongoDB (Change Stream) Watcher

*   MongoDB watcher uses [change streams](https://docs.mongodb.com/manual/changeStreams/) introduced in MongoDB v3.6 to track [change events](https://docs.mongodb.com/manual/reference/change-events/).
*   After reading the records from change stream, they are written to AWS Kinesis stream(s).
*   This project uses [packer](https://www.packer.io) to build a Ubuntu docker image and push it to Amazon Elastic Container registry.

### Stateless

*   Process state like last read MongoDB record is stored in DynamoDB.
*   This allows the container to be restarted without loosing and state or missing MongoDB records.

### Container support

*   This implementation runs as a Docker image in AWS Fargate/ECS.
*   All the required parameters are passed as environment variables to running image.
*   Passwords are stored in AWS SSM.

### Pre-requisite

1.   This is a Python 3.6 project that involves AWS components.
1.   Make sure you have [virtualenv](https://virtualenv.pypa.io/en/stable/) or else install it using pip

     ```bash
     [sudo] pip install virtualenv
     ```

     More information on installation can be found [here](https://virtualenv.pypa.io/en/stable/installation/).
1.   You can use your favourite Python editor. We've been using [PyCharm](https://www.jetbrains.com/pycharm/specials/pycharm/pycharm.html).

### Get Started

1.   Run [setup.sh](./setup.sh) to setup the dev environment or follow the below steps to do it yourself.
1.   Import the project into PyCharm and set project SDK Python.
     -   File -> Project Structure.
     -   Select *mongo-change-stream* and then select *Dependencies*.
     -   In *Module SDK* click *New* and select *Python SDK*.
     -   Browse and select virtual_env/bin/python3.
     -   Click *Ok* after selecting this new Python SDK.

### Creating container image

*   Packer and Ansible are used to build Docker image.
*   Note that you might need to create a new repository in ECR (Amazon Elastic Container Registry) for the first time.
*   Here's the command to create repository in ECR.

    ```bash
    aws ecr create-repository --repository-name 2ki/mongo-change-stream --profile default
    ````

*   Assuming you have already setup the environment by running [setup.sh](./setup.sh), activate the python virtual environment using below command.

    ```bash
    source virtual_env/bin/activate
    ```
*   Here's the command to create an image:

    ```bash
    packer build -var 'aws_region=ap-southeast-2' -var 'timezone=Australia/ACT' -var 'aws_account_id=111111111111' change_stream.json
    ```

*   The image will be build and pushed to Amazon Elastic Container registry.
*   Packer config [change_stream.json](./packer/change_stream.json) runs the Ansible provisioner [provision.yml](./packer/provision.yml). Both of them are quiet straight forward to understand with basic Packer and Ansible knowledge.
*   The latest image tag will be stored in [image_tag](./packer/image_tag).
*   [image_tag](./packer/image_tag) will be used by Terraform to determine if container image in ECS needs an update.


### How to test mongo watcher locally?

There are two ways to test the watcher locally.

1.   Directly run the watcher code without packaging it into a docker image.
     This might be a good option to debug the watcher code.
     - Run [test_mongo_watcher.py](./test_mongo_watcher.py) to call mongo watcher's `main()` method.
     - Before running [test_mongo_watcher.py](./test_mongo_watcher.py), set the right values for the enviroment variables in the file.
1.   Create a local docker image and run it.
     This might be a good option to test the image before deploying it into AWS ECR.
     -   Create an docker image:
    
         ```bash
         packer build -var 'aws_region=ap-southeast-2' -var 'timezone=Australia/ACT' change_stream_local.json
         ```
     -   Once the image is created it will be tagged as 'latest'.
     -   Run the image using [change_stream_start.sh](./packer/change_stream_start.sh) script.
     -   Example:

         ```bash
         ./change_stream_start.sh 2ki/mongo-change-stream
         ```
     -   You can open a bash shell on the running container.

         ```bash
         docker exec -it $(docker ps --filter "ancestor=2ki/mongo-change-stream" -q) bash
         ```
     -   If you want to stop the container use below command.

         ```bash
         docker stop $(docker ps --filter "ancestor=2ki/mongo-change-stream" -q)
         ```
     -   Few useful Docker commands:
         -   ```docker images``` : List all images.
         -   ```docker ps``` : List running containers.
         -   ```docker ps -a``` : List all containers including stopped.
         -   ```docker rm $(docker ps -a -q)``` : Remove all containers.
         -   ```docker rmi $(docker images -q)``` : Remove all images.

### List of environment variables to start container

| Environment variable | Description                                                  |
| :------------------- | :----------------------------------------------------------- |
| AWS_DEFAULT_REGION   | AWS region name.                                             |
| MONGODB_URI          | MongoDB connection URI. Supports both [replica set][rsurl] and [DNS seedlist][rsurl] connection format. |
| MONGODB_USERNAME     | MongoDB username.                                            |
| MONGODB_PASSWORD     | MongoDB password.                                            |
| MONGODB_DATABASE     | MongoDB database name.                                       |
| MONGODB_COLLECTION   | MongoDB collection to watch.                                 |
| OUT_KINESIS_STREAM   | AWS Kinesis stream name to write records to.                 |
| KINESIS_PUT_RETRIES  | Max number of retries while writing to kinesis stream.       |
| DYNAMODB_TABLE_NAME  | DynamoDB table name to store the marker for last successfully read record. If not provided, no markers will be stored and in case of restart, the watcher will resume from latest record. |

## Deploying the pipeline to AWS

-   The pipeline is fully automated using Terraform expect setting up Snowpipe.
-   Basic directory structure of Terraform environment.

    ```
    Terraform/
    └── environments
        └── dev   -----------------------------------------------------> DEV environment
            ├── variables.tf
            ├── main.tf  ----------------------------------------------> Main Terraform pipeline
            ├── output.tf
            └── provider.tf
    ```
### Fresh deployment

-   Create a new AWS ECR repository with name `2ki/mongo-change-stream`. Look at the topic *Creating container image* for help.
-   Store MongoDB password into a [AWS parameter store][pstore] key and the key name should match the one mentioned in the Terraform variable *ssm_key_name*.
-   Follow the guidelines under *Creating container image* to create the image.
-   Navigate to the right environment under the [Terraform](./Terraform/environments) directory and execute following commands.

    ```bash
    terraform init
    terraform apply
    ```
-   Type `yes` if you are satisfied with what Terraform is about to create.

### Deployment procedure if MongoDB watcher has changed

-   In case you have modified [mongo_watcher.py](./mongo_watcher.py), a new Docker image has to be created and pushed to ECR.
-   Follow the guidelines under *Creating container image* to create the image.
-   Navigate to the right environment under the [Terraform](./Terraform/environments) directory and execute following commands.

    ```bash
    terraform init
    terraform apply
    ```
-   Type `yes` if you are satisfied with what Terraform is about to create.
-   Terraform will update the ECS service with the new image from ECR.


[pstore]: https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html
[rsurl]: https://docs.mongodb.com/manual/reference/connection-string/
