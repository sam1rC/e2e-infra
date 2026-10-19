output "distribution_id" {
  description = "ID de la distribución (invalidaciones tras desplegar el frontend)."
  value       = module.site.distribution_id
}

output "distribution_domain_name" {
  description = "Dominio *.cloudfront.net (destino del CNAME si el DNS es externo)."
  value       = module.site.distribution_domain_name
}

output "site_bucket_id" {
  description = "Bucket donde el pipeline sube el frontend."
  value       = module.site.bucket_id
}

output "site_kms_key_arn" {
  description = "CMK del bucket del sitio (el pipeline necesita kms:GenerateDataKey sobre ella)."
  value       = module.site.kms_key_arn
}

output "api_invoke_url" {
  description = "URL de la etapa (directa: el WAF regional la bloquea sin la cabecera x-origin-verify de CloudFront)."
  value       = module.api.invoke_url
}

output "usage_plan_ids" {
  description = "Planes de uso por tier: el onboarding asocia la API key del tenant al de su tier."
  value       = module.api.usage_plan_ids
}

output "api_function_name" {
  description = "Nombre de la Lambda de la API."
  value       = module.api_function.function_name
}

output "tenant_role_arn" {
  description = "Rol ABAC que la Lambda asume con la etiqueta de sesión del tenant."
  value       = module.tenant_role.role_arn
}

output "user_pool_id" {
  description = "ID del user pool compartido de tenants."
  value       = module.tenants.user_pool_id
}

output "user_pool_client_ids" {
  description = "IDs de los app clients."
  value       = module.tenants.client_ids
}

output "table_name" {
  description = "Tabla pool (clave de partición tenant_id)."
  value       = module.table.table_name
}

output "alarm_topic_arns" {
  description = "Topics SNS de alarmas: regional y de borde (us-east-1)."
  value       = { regional = module.alarms.topic_arn, edge = module.edge_alarms.topic_arn }
}

output "dashboard_name" {
  description = "Dashboard de CloudWatch del blueprint."
  value       = module.dashboard.dashboard_name
}

output "backup_vault_name" {
  description = "Vault de AWS Backup del entorno."
  value       = module.backup.vault_name
}
