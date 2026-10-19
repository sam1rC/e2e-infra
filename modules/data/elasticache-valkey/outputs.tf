output "replication_group_id" {
  description = "ID del replication group: es el \"nombre de host\" que firma el token IAM (no el endpoint)."
  value       = aws_elasticache_replication_group.this.replication_group_id
}

output "replication_group_arn" {
  description = "ARN del replication group."
  value       = aws_elasticache_replication_group.this.arn
}

output "primary_endpoint" {
  description = "Endpoint del nodo primario (lecturas y escrituras)."
  value       = aws_elasticache_replication_group.this.primary_endpoint_address
}

output "reader_endpoint" {
  description = "Endpoint de lectura (reparte entre las réplicas)."
  value       = aws_elasticache_replication_group.this.reader_endpoint_address
}

output "port" {
  description = "Puerto de Valkey."
  value       = var.port
}

output "security_group_id" {
  description = "Security group del cache (sin reglas de salida)."
  value       = aws_security_group.this.id
}

output "iam_user_names" {
  description = "Nombre del usuario de ElastiCache por clave de iam_users: es el valor de `User` al firmar el token IAM."
  value       = { for k, u in aws_elasticache_user.app : k => u.user_name }
}

output "iam_connect_resource_arns" {
  description = "ARNs para elasticache:Connect, por clave de iam_users: [replication group, usuario]. Úsalos en el task role de la aplicación (ambos ARN son necesarios)."
  value       = { for k, u in aws_elasticache_user.app : k => [aws_elasticache_replication_group.this.arn, u.arn] }
}

output "log_group_names" {
  description = "Log groups de slow-log y engine-log."
  value       = { for k, g in aws_cloudwatch_log_group.this : k => g.name }
}
