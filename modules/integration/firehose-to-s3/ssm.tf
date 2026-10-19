locals {
  ssm_parameters = var.publish_ssm_parameters ? {
    "firehose_stream_name" = aws_kinesis_firehose_delivery_stream.this.name
    "firehose_stream_arn"  = aws_kinesis_firehose_delivery_stream.this.arn
  } : {}
}

# Solo nombre y ARN: ningún valor sensible (ADR 0004).
resource "aws_ssm_parameter" "this" {
  for_each = local.ssm_parameters

  name  = "${local.ssm_prefix}/${each.key}"
  type  = "String"
  value = each.value

  tags = var.tags
}
