locals {
  ssm_parameters = var.publish_ssm_parameters ? {
    "backup_vault_name" = aws_backup_vault.this.name
    "backup_vault_arn"  = aws_backup_vault.this.arn
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
