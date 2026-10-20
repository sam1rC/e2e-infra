output "vpc_id" {
  description = "ID de la VPC."
  value       = module.vpc.vpc_id
}

output "subnet_ids" {
  description = "Subredes por capa (public, app, data), en el orden de az_names."
  value       = module.vpc.subnet_ids
}

output "nat_gateway_ids" {
  description = "NAT por clave (AZ)."
  value       = module.vpc.nat_gateway_ids
}

output "kms_key_arn" {
  description = "CMK de plataforma del entorno."
  value       = module.kms.key_arn
}

output "logs_bucket_name" {
  description = "Bucket de flow logs y logs de acceso del ALB."
  value       = module.logs.bucket_id
}

output "endpoints_security_group_id" {
  description = "Security group de los endpoints de interfaz (las capas consumidoras le añaden su regla 443)."
  value       = module.endpoints.security_group_id
}

output "alarm_topic_arn" {
  description = "Topic SNS de alarmas del entorno, compartido por todas las capas."
  value       = module.notifications.topic_arn
}

output "ssm_prefix" {
  description = "Prefijo SSM con las salidas de la capa (ADR 0004)."
  value       = "/${var.project}/${var.environment}/network"
}
