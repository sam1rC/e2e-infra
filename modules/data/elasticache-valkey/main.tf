resource "aws_elasticache_subnet_group" "this" {
  name        = local.name
  description = "Subredes de datos de ${local.name}"
  subnet_ids  = var.subnet_ids

  tags = merge(var.tags, { Name = local.name })
}

resource "aws_elasticache_parameter_group" "this" {
  name        = local.name
  description = "Parametros de ${local.name}"
  family      = "valkey${local.engine_major}"

  parameter {
    name  = "maxmemory-policy"
    value = var.maxmemory_policy
  }

  tags = merge(var.tags, { Name = local.name })
}

# ElastiCache escribe en estos grupos; se crean antes con retención y cifrado con la CMK.
resource "aws_cloudwatch_log_group" "this" {
  for_each = local.log_types

  name              = each.value.group
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id = local.name
  description          = "Valkey ${local.name}"
  engine               = "valkey"
  engine_version       = var.engine_version
  node_type            = var.node_type
  port                 = var.port
  parameter_group_name = aws_elasticache_parameter_group.this.name

  num_cache_clusters         = local.num_cache_clusters
  automatic_failover_enabled = local.has_replicas
  multi_az_enabled           = local.has_replicas

  subnet_group_name  = aws_elasticache_subnet_group.this.name
  security_group_ids = [aws_security_group.this.id]

  # Cifrado en tránsito y en reposo; sin AUTH token: solo usuarios con autenticación IAM.
  transit_encryption_enabled = true
  transit_encryption_mode    = "required"
  at_rest_encryption_enabled = true
  kms_key_id                 = var.kms_key_arn
  user_group_ids             = [aws_elasticache_user_group.this.user_group_id]

  snapshot_retention_limit  = var.snapshots.retention_days
  snapshot_window           = var.snapshots.retention_days > 0 ? var.snapshots.window : null
  maintenance_window        = var.snapshots.maintenance_window
  final_snapshot_identifier = var.final_snapshot_enabled ? "${local.name}-final" : null

  auto_minor_version_upgrade = "true"
  apply_immediately          = var.apply_immediately

  dynamic "log_delivery_configuration" {
    for_each = local.log_types

    content {
      destination      = aws_cloudwatch_log_group.this[log_delivery_configuration.key].name
      destination_type = "cloudwatch-logs"
      log_format       = "json"
      log_type         = log_delivery_configuration.value.type
    }
  }

  tags = merge(var.tags, { Name = local.name })
}
