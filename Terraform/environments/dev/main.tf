#--------------------------------------------------------------
# Resources
#
# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html
# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definitions.html
# Splat syntax
# https://www.terraform.io/docs/configuration-0-11/interpolation.html#attributes-of-a-data-source
# https://blog.gruntwork.io/terraform-tips-tricks-loops-if-statements-and-gotchas-f739bbae55f9
# Systems manager (SSM key store)
# https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-paramstore-access.html
#--------------------------------------------------------------
data "aws_caller_identity" "current" {}

resource "aws_iam_role" "task_exec" {
  description = "ECS task execution role."
  name        = "MongoCSFargate-TaskExecutionRole-${var.env_tag}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}
resource "aws_iam_role_policy_attachment" "task_exec_service" {
  role       = "${aws_iam_role.task_exec.id}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
resource "aws_iam_role_policy" "ssm" {
  name  = "SSM"
  role  = "${aws_iam_role.task_exec.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameters"
      ],
      "Resource": [
        "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.ssm_key_prefix}"
      ]
    }
  ]
}
EOF
}

resource "aws_security_group" "ecs" {
  name        = "MongoCSFargate-${var.env_tag}"
  description = "Security group for Fargate MongoDB Change Stream"
  vpc_id      = "${var.vpc_id}"

  tags {
    Name = "MongoCSFargate-${var.env_tag}"
  }
}
resource "aws_security_group_rule" "allow-outbound" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.ecs.id}"
}

resource "aws_cloudwatch_log_group" "ecs" {
  count             = "${length(var.collections_to_watch)}"
  name              = "/ecs/2ki/MongoChangeStreamWatcher/${element(var.collections_to_watch, count.index)}"
  retention_in_days = "${lookup(var.log_retintion_days, element(var.collections_to_watch, count.index), "2")}"
  tags = {
    Environment = "${var.env_tag}"
    Collection  = "${element(var.collections_to_watch, count.index)}"
  }
}


resource "aws_ecs_cluster" "main" {
  name = "FargateMarketplaceCluster-${var.env_tag}"
}

resource "aws_ecs_task_definition" "mongo" {
  count                    = "${length(var.collections_to_watch)}"
  family                   = "${element(var.collections_to_watch, count.index)}-ChangeStreamWatcher"
  cpu                      = "${lookup(var.fargate_cpu, element(var.collections_to_watch, count.index), "256")}"
  memory                   = "${lookup(var.fargate_memory, element(var.collections_to_watch, count.index), "512")}"
  network_mode             = "awsvpc"
  execution_role_arn       = "${aws_iam_role.task_exec.arn}"
  requires_compatibilities = ["FARGATE"]

  container_definitions = <<EOF
[
  {
    "name"   : "${element(var.collections_to_watch, count.index)}-Watcher",
    "image"  : "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.app_image}",
    "cpu"    :  ${lookup(var.fargate_cpu, element(var.collections_to_watch, count.index), "256")},
    "memory" :  ${lookup(var.fargate_memory, element(var.collections_to_watch, count.index), "512")},
    "environment" : [
      { "name" : "AWS_DEFAULT_REGION", "value" : "${var.aws_region}" },
      { "name" : "LOG_LEVEL",          "value" : "${lookup(var.log_level, element(var.collections_to_watch, count.index), "INFO")}" },
      { "name" : "MONGODB_URI",        "value" : "${var.mongodb_uri[element(var.collections_to_watch, count.index)]}" },
      { "name" : "MONGODB_USERNAME",   "value" : "${var.mongodb_username[element(var.collections_to_watch, count.index)]}" },
      { "name" : "MONGODB_DATABASE",   "value" : "${var.mongodb_database[element(var.collections_to_watch, count.index)]}" },
      { "name" : "MONGODB_COLLECTION", "value" : "${element(var.collections_to_watch, count.index)}" }
    ],
    "secrets": [
      {
        "name"      : "MONGODB_PASSWORD",
        "valueFrom" : "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.ssm_key}"
      }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group"         : "${element(aws_cloudwatch_log_group.ecs.*.name, count.index)}",
        "awslogs-region"        : "${var.aws_region}",
        "awslogs-stream-prefix" : "watcher"
      }
    }
  }
]
EOF
}

resource "aws_ecs_service" "mongo-cs" {
  count           = "${length(var.collections_to_watch)}"
  name            = "MongoChangeStreamWatcher-${element(var.collections_to_watch, count.index)}"
  cluster         = "${aws_ecs_cluster.main.id}"
  task_definition = "${element(aws_ecs_task_definition.mongo.*.arn, count.index)}"
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = "${var.subnet_ids}"
    security_groups = ["${aws_security_group.ecs.id}"]
  }
}