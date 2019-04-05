#--------------------------------------------------------------
# Outputs
#--------------------------------------------------------------
output "task_exec_iam_role_name" {
  value = "${aws_iam_role.task_exec.name}"
}
output "task_iam_role_name" {
  value = "${aws_iam_role.task.name}"
}

output "ecs_security_group_name" {
  value = "${aws_security_group.ecs.name}"
}
output "ecs_security_group_id" {
  value = "${aws_security_group.ecs.id}"
}

output "ecs_cloudwatch_log_group_names" {
  value = "${aws_cloudwatch_log_group.ecs.*.name}"
}

output "this_ecs_cluster_name" {
  value = "${aws_ecs_cluster.main.name}"
}
output "this_ecs_task_definitions" {
  value = "${aws_ecs_task_definition.mongo.*.id}"
}
output "this_ecs_service_names" {
  value = "${aws_ecs_service.mongo-cs.*.name}"
}

output "raw_kinesis_stream_name" {
  value = "${aws_kinesis_stream.raw.name}"
}
output "raw_kinesis_stream_shard_count" {
  value = "${aws_kinesis_stream.raw.shard_count}"
}
output "raw_kinesis_stream_retention_period" {
  value = "${aws_kinesis_stream.raw.retention_period}"
}