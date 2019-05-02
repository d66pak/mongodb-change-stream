#--------------------------------------------------------------
# Variables used by all the *.tf
#--------------------------------------------------------------
variable "env_tag" {
  description = "Suffix to be appended to aws resouce name"
  default = "Dev"
}
variable "project_tag" {
  description = "Common project tag used across all the resources."
  default = "mongo-change-stream"
}
variable "aws_region" {
  default = "ap-southeast-2"
}
variable "aws_profile" {
  default = "default"
}
variable "ecr_repo_name" {
  description = "ECR repository name."
  default = "2ki/mongo-change-stream"
}
variable "vpc_id" {
  description = "VPC id"
  default = "vpc-ca9c8fa8"
}
variable "subnet_ids" {
  description = "Subnet id list"
  type = "list"
  default = ["subnet-a9043edd"]
}
variable "security_group_name" {
  description = "Name of AWS security group"
  default = "MongoCSFargate"
}

variable "fargate_task_role_name" {
  description = "Task role name for Fargate container"
  default = "MongoDBChangeStreamTaskRole"
}
variable "fargate_task_execution_role_name" {
  description = "Task execution role name for Fargate tasks"
  default = "MongoDBChangeStreamTaskExecRole"
}
variable "fargate_log_group_prefix" {
  description = "Prefix path for AWS log group"
  default = "2ki/MongoCSFargate"
}
variable "fargate_cluster_name" {
  description = "Fargate cluster name"
  default = "FargateCluster"
}

variable "app_image" {
  description = "Docker image (repository:tag) in ECR repository to run in the ECS cluster"
  default     = "2ki/mongo-change-stream:latest"
}

variable "ssm_key_prefix" {
  description = "SSM key prefix to grant access"
  default     = "/mongodb/*"
}

variable "raw_kinesis_stream_name" {
  description = "A name to identify the stream. This is unique to the AWS account and region the Stream is created in."
  default = "out_kinesis_stream"
}
variable "raw_kinesis_shard_count" {
  description = "The number of shards that the stream will use."
  default = 1
}
variable "raw_kinesis_retention_period" {
  description = "Length of time (in hours) data records are accessible after they are added to the stream."
  default = 48
}

variable "collections_to_watch" {
  description = "MongoDB collections to watch"
  type         = "list"

  default = ["CollectionA", "CollectionB"]
}

variable "fargate_cpu" {
  description = "The number of cpu units used by the task or container. (1 vCPU = 1024 CPU units)"
  type = "map"

  default = {
    CollectionA = "256"
    CollectionB = "256"
  }
}
variable "fargate_memory" {
  description = "The amount (in MiB) of memory used by the task or container"
  type = "map"

  default = {
    CollectionA = "512"
    CollectionB = "512"
  }
}
variable "log_retintion_days" {
  description = "Cloudwatch log retention id days"
  type = "map"

  default = {
    CollectionA = "3"
    CollectionB = "3"
  }
}
variable "log_level" {
  description = "Container log level"
  type = "map"

  default = {
    CollectionA = "DEBUG"
    CollectionB = "DEBUG"
  }
}
variable "mongodb_uri" {
  description = "MongoDB URI"
  type = "map"

  default = {
    CollectionA = "mongodb+srv://test-dev-kfz7z.gcp.mongodb.net/test?authSource=admin"
    CollectionB = "mongodb+srv://test-dev-kfz7z.gcp.mongodb.net/test?authSource=admin"
  }
}
variable "mongodb_username" {
  description = "MongoDB username"
  type = "map"

  default = {
    CollectionA = "read-only_username"
    CollectionB = "read-only_username"
  }
}
variable "mongodb_database" {
  description = "MongoDB database"
  type = "map"

  default = {
    CollectionA = "test"
    CollectionB = "test"
  }
}
variable "ssm_key_name" {
  description = "SSM full key name for each collection"
  type = "map"

  default = {
    CollectionA = "/mongodb/readonly"
    CollectionB = "/mongodb/readonly"
  }
}
variable "kinesis_put_retries" {
  description = "Max attempts to put records into Kinesis stream"
  type = "map"

  default = {
    CollectionA = "5"
    CollectionB = "5"
  }
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table to store MongoDB record ids"
  default = "MongoDBChangeStreamTracker"
}

variable "terraform_state_s3_root" {
  description = "Root S3 bucket where all the state files are stored"
  default = "dev.terraform.state"
}
variable "terraform_state_s3_key" {
  description = "State file name"
  default = "mongo-change-stream/terraform.tfstate"
}

#--------------------------------------------------------------
# Write terraform state to S3 bucket
#--------------------------------------------------------------
terraform {
  backend "s3" {
    bucket = "dev.terraform.state"
    key    = "mongo-change-stream/terraform.tfstate"
    region = "ap-southeast-2"
  }
}

#--------------------------------------------------------------
# Read terraform state from S3 bucket
#--------------------------------------------------------------
data "terraform_remote_state" "network" {
  backend = "s3"
  config {
    bucket  = "${var.terraform_state_s3_root}"
    key     = "${var.terraform_state_s3_key}"
    region  = "${var.aws_region}"
    encrypt = true
  }
}

#--------------------------------------------------------------
# Setup some relative paths (NOTE: Don't modify)
#--------------------------------------------------------------
locals {
  proj_dir   = "${path.module}/../../.."
  script_dir = "${path.module}/../../../scripts"
  build_dir  = "${path.module}/build"
}
