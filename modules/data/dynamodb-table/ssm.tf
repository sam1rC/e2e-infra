locals {
  ssm_parameters = var.publish_ssm_parameters ? merge(
    {
      "table_name" = aws_dynamodb_table.this.name
      "table_arn"  = aws_dynamodb_table.this.arn
    },
    var.stream_view_type == null ? null : { "stream_arn" = aws_dynamodb_table.this.stream_arn },
  ) : {}
}

# Solo nombres y ARNs: ningún valor sensible (ADR 0004).
resource "aws_ssm_parameter" "this" {
  for_each = local.ssm_parameters

  name  = "${local.ssm_prefix}/${each.key}"
  type  = "String"
  value = each.value

  tags = var.tags
}
