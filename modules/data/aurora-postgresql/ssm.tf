locals {
  ssm_parameters = var.publish_ssm_parameters ? {
    "writer_endpoint"   = aws_rds_cluster.this.endpoint
    "reader_endpoint"   = aws_rds_cluster.this.reader_endpoint
    "port"              = tostring(aws_rds_cluster.this.port)
    "database_name"     = var.database_name
    "cluster_arn"       = aws_rds_cluster.this.arn
    "app_secret_arn"    = module.app_secret.secret_arn
    "master_secret_arn" = aws_rds_cluster.this.master_user_secret[0].secret_arn
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
