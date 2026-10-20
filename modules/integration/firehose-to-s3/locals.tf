locals {
  stream_name = "${var.project}-${var.environment}-${var.name}"

  # ARN construido con el nombre: el trust del rol no puede depender del stream (que depende del rol).
  stream_arn = "arn:${data.aws_partition.current.partition}:firehose:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:deliverystream/${local.stream_name}"

  partitioned = var.dynamic_partitioning != null

  date_partition = "!{timestamp:yyyy/MM/dd}/"
  prefix = local.partitioned ? (
    "${var.prefix}!{partitionKeyFromQuery:${var.dynamic_partitioning.key_name}}/${local.date_partition}"
  ) : "${var.prefix}${local.date_partition}"
  error_prefix = "${var.error_prefix}!{firehose:error-output-type}/${local.date_partition}"

  log_group_name  = "/aws/kinesisfirehose/${local.stream_name}"
  log_stream_name = "S3Delivery"

  ssm_prefix = "/${var.project}/${var.environment}/integration"
}
