output "vpc_id" {
  description = "ID de la VPC."
  value       = module.network.vpc_id
}

output "subnet_ids" {
  description = "Subredes por capa (public, app, data), en el orden de az_names."
  value       = module.network.subnet_ids
}

output "nat_gateway_ids" {
  description = "NAT por clave (AZ)."
  value       = module.network.nat_gateway_ids
}

output "nat_mode" {
  description = "Modo de NAT aplicado (según el entorno si nat_mode es null)."
  value       = module.network.nat_mode
}

output "kms_key_arn" {
  description = "CMK de plataforma del entorno."
  value       = module.network.kms_key_arn
}

output "logs_bucket_name" {
  description = "Bucket de flow logs y logs de acceso del ALB."
  value       = module.network.logs_bucket_name
}

output "endpoints_security_group_id" {
  description = "Security group de los endpoints de interfaz (las capas consumidoras le añaden su regla 443)."
  value       = module.network.endpoints_security_group_id
}

output "alarm_topic_arn" {
  description = "Topic SNS de alarmas del entorno, compartido por todas las capas."
  value       = module.network.alarm_topic_arn
}

output "ssm_prefix" {
  description = "Prefijo SSM con las salidas de la capa (ADR 0004)."
  value       = module.network.ssm_prefix
}
