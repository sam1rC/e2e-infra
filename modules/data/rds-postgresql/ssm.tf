locals {
  ssm_parameters = var.publish_ssm_parameters ? {
    "endpoint"          = aws_db_instance.this.address
    "port"              = tostring(aws_db_instance.this.port)
    "database_name"     = var.database_name
    "instance_arn"      = aws_db_instance.this.arn
    "app_secret_arn"    = module.app_secret.secret_arn
    "master_secret_arn" = aws_db_instance.this.master_user_secret[0].secret_arn
  } : {}
}

# Solo endpoints y ARNs: ningún valor sensible (ADR 0004).
resource "aws_ssm_parameter" "this" {
  for_each = local.ssm_parameters

  name  = "${local.ssm_prefix}/${each.key}"
  type  = "String"
  value = each.value

  tags = var.tags
}
