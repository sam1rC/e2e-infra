output "alb_arn" {
  description = "ARN del ALB interno (origen del VPC origin de la capa edge)."
  value       = module.alb.alb_arn
}

output "alb_dns_name" {
  description = "DNS del ALB interno (solo resuelve a IPs privadas)."
  value       = module.alb.alb_dns_name
}

output "ecr_repository_url" {
  description = "Repositorio ECR de la aplicación (imágenes por digest)."
  value       = module.ecr.repository_url
}

output "cluster_name" {
  description = "Cluster ECS."
  value       = module.cluster.cluster_name
}

output "service_name" {
  description = "Servicio ECS de la aplicación."
  value       = module.service.service_name
}

output "task_role_arn" {
  description = "Rol de la aplicación (task role): identidad para permisos adicionales."
  value       = module.service.task_role_arn
}

output "task_role_name" {
  description = "Nombre del task role, para adjuntar políticas desde una capa que envuelva esta."
  value       = module.service.task_role_name
}

output "service_security_group_id" {
  description = "Security group de las tareas."
  value       = module.service.security_group_id
}

output "dashboard_name" {
  description = "Dashboard de CloudWatch del entorno."
  value       = module.dashboard.dashboard_name
}

output "event_bus_name" {
  description = "Bus de eventos de dominio."
  value       = module.events.bus_name
}

output "data_lake_bucket_id" {
  description = "Bucket del data lake (eventos particionados por fecha)."
  value       = module.data_lake.bucket_id
}
