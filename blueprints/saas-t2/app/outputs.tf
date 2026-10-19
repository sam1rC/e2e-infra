output "alb_arn" {
  description = "ARN del ALB interno (origen del VPC origin de la capa edge)."
  value       = module.app.alb_arn
}

output "alb_dns_name" {
  description = "DNS del ALB interno (solo resuelve a IPs privadas)."
  value       = module.app.alb_dns_name
}

output "ecr_repository_url" {
  description = "Repositorio ECR de la aplicación (imágenes por digest)."
  value       = module.app.ecr_repository_url
}

output "cluster_name" {
  description = "Cluster ECS."
  value       = module.app.cluster_name
}

output "service_name" {
  description = "Servicio ECS de la aplicación."
  value       = module.app.service_name
}

output "task_role_arn" {
  description = "Rol de la aplicación (task role): identidad para permisos adicionales."
  value       = module.app.task_role_arn
}

output "task_role_name" {
  description = "Nombre del task role, para adjuntar políticas desde una capa que envuelva esta."
  value       = module.app.task_role_name
}

output "service_security_group_id" {
  description = "Security group de las tareas."
  value       = module.app.service_security_group_id
}

output "dashboard_name" {
  description = "Dashboard de CloudWatch del entorno."
  value       = module.app.dashboard_name
}

output "user_pool_id" {
  description = "ID del user pool compartido de tenants."
  value       = module.tenants.user_pool_id
}

output "user_pool_client_ids" {
  description = "IDs de los app clients."
  value       = module.tenants.client_ids
}

output "tenant_role_arn" {
  description = "Rol ABAC que la aplicación asume con la etiqueta de sesión del tenant."
  value       = module.tenant_role.role_arn
}

output "tenant_bucket_id" {
  description = "Bucket de datos de tenants (prefijo tenants/<tenant>/)."
  value       = module.tenant_bucket.bucket_id
}
