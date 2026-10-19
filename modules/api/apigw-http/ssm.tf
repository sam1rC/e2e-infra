locals {
  ssm_parameters = var.publish_ssm_parameters ? {
    "api_id"        = aws_apigatewayv2_api.this.id
    "api_endpoint"  = aws_apigatewayv2_api.this.api_endpoint
    "execution_arn" = aws_apigatewayv2_api.this.execution_arn
  } : {}
}

# Solo identificadores y endpoints públicos (ADR 0004).
resource "aws_ssm_parameter" "this" {
  for_each = local.ssm_parameters

  name  = "${local.ssm_prefix}/${each.key}"
  type  = "String"
  value = each.value

  tags = var.tags
}
