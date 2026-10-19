output "cluster_arn" {
  description = "ARN del cluster."
  value       = aws_ecs_cluster.this.arn
}

output "cluster_name" {
  description = "Nombre del cluster."
  value       = aws_ecs_cluster.this.name
}

output "capacity_providers" {
  description = "Capacity providers habilitados (FARGATE y, fuera de prod, FARGATE_SPOT)."
  value       = local.capacity_providers
}

output "exec_enabled" {
  description = "true si el cluster tiene ECS Exec configurado con registro cifrado."
  value       = local.enable_exec
}

output "exec_log_group_name" {
  description = "Nombre del log group de las sesiones de ECS Exec (null si ECS Exec está desactivado)."
  value       = try(aws_cloudwatch_log_group.exec[0].name, null)
}
