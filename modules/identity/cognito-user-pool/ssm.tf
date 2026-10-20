locals {
  ssm_parameters = var.publish_ssm_parameters ? merge(
    {
      "user_pool_id"  = aws_cognito_user_pool.this.id
      "user_pool_arn" = aws_cognito_user_pool.this.arn
      "issuer"        = "https://${aws_cognito_user_pool.this.endpoint}"
    },
    { for k, c in aws_cognito_user_pool_client.this : "client_id/${k}" => c.id },
  ) : {}
}

# Solo identificadores públicos (los IDs de cliente viajan en los tokens): nada sensible (ADR 0004).
resource "aws_ssm_parameter" "this" {
  for_each = local.ssm_parameters

  name  = "${local.ssm_prefix}/${each.key}"
  type  = "String"
  value = each.value

  tags = var.tags
}
