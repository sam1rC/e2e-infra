locals {
  ssm_parameters = var.publish_ssm_parameters ? {
    "event_bus_name" = aws_cloudwatch_event_bus.this.name
    "event_bus_arn"  = aws_cloudwatch_event_bus.this.arn
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
