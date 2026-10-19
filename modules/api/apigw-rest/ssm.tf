locals {
  ssm_parameters = var.publish_ssm_parameters ? merge(
    {
      "rest_api_id" = aws_api_gateway_rest_api.this.id
      "invoke_url"  = aws_api_gateway_stage.this.invoke_url
    },
    { for k, p in aws_api_gateway_usage_plan.this : "usage_plan_id/${k}" => p.id },
  ) : {}
}

# Solo identificadores y URLs (ADR 0004); las API keys nunca se publican.
resource "aws_ssm_parameter" "this" {
  for_each = local.ssm_parameters

  name  = "${local.ssm_prefix}/${each.key}"
  type  = "String"
  value = each.value

  tags = var.tags
}
