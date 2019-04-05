#--------------------------------------------------------------
# Variables used by all the *.tf
#--------------------------------------------------------------

variable "package_file" {
  description = "Lambda Zip file name; must be under 'build' directory"
  default     = ""
}
variable "env_tag" {
  description = "Suffix to be appended to aws resouce name"
  default = "Dev_Au"
}
variable "aws_region" {
  default = "ap-southeast-2"
}
variable "aws_profile" {
  default = "default"
}

variable "vpc_id" {
  default = "vpc-cxxxxxx"
}
variable "subnet_ids" {
  type = "list"
  default = ["subnet-axxxxxxx"]
}

variable "app_image" {
  description = "Docker image (repository:tag) in ECR repository to run in the ECS cluster"
  default     = "2ki/mongo-change-stream:latest"
}

variable "ssm_key_prefix" {
  description = "SSM key prefix to grant access"
  default     = "/mongodb/*"
}
variable "ssm_key" {
  description = "SSM key name"
  default     = "/mongodb/readonly"
}

variable "kinesis_stream_name" {
  description = "A name to identify the stream. This is unique to the AWS account and region the Stream is created in."
  default = "out_kinesis_stream"
}
variable "kinesis_shard_count" {
  description = "The number of shards that the stream will use."
  default = 1
}
variable "kinesis_retention_period" {
  description = "Length of time (in hours) data records are accessible after they are added to the stream."
  default = 48
}

variable "collections_to_watch" {
  description = "MongoDB collections to watch"
  type         = "list"

  default = ["Customers", "Orderlines"]
}

variable "fargate_cpu" {
  description = "The number of cpu units used by the task or container. (1 vCPU = 1024 CPU units)"
  type = "map"

  default = {
    Customers = "256"
    Orderlines = "256"
  }
}
variable "fargate_memory" {
  description = "The amount (in MiB) of memory used by the task or container"
  type = "map"

  default = {
    Customers = "512"
    Orderlines = "512"
  }
}
variable "log_retintion_days" {
  description = "Cloudwatch log retention id days"
  type = "map"

  default = {
    Customers = "3"
    Orderlines = "3"
  }
}
variable "log_level" {
  description = "Container log level"
  type = "map"

  default = {
    Customers = "DEBUG"
    Orderlines = "DEBUG"
  }
}
variable "mongodb_uri" {
  description = "MongoDB URI"
  type = "map"

  default = {
    Customers = "mongodb+srv://mongo-dev-kfz7z.gcp.mongodb.net/test?authSource=admin"
    Orderlines = "mongodb+srv://mongo-dev-kfz7z.gcp.mongodb.net/test?authSource=admin"
  }
}
variable "mongodb_username" {
  description = "MongoDB username"
  type = "map"

  default = {
    Customers = "read-only"
    Orderlines = "read-only"
  }
}
variable "mongodb_database" {
  description = "MongoDB database"
  type = "map"

  default = {
    Customers = "test_db"
    Orderlines = "test_db"
  }
}
variable "kinesis_put_retries" {
  description = "Max attempts to put records into Kinesis stream"
  type = "map"

  default = {
    Customers = "5"
    Orderlines = "5"
  }
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
