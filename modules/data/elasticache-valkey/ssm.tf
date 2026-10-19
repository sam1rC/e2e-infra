locals {
  ssm_parameters = var.publish_ssm_parameters ? {
    "primary_endpoint"      = aws_elasticache_replication_group.this.primary_endpoint_address
    "reader_endpoint"       = aws_elasticache_replication_group.this.reader_endpoint_address
    "port"                  = tostring(var.port)
    "replication_group_id"  = aws_elasticache_replication_group.this.replication_group_id
    "replication_group_arn" = aws_elasticache_replication_group.this.arn
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
