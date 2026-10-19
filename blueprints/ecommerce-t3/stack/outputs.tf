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

output "api_endpoint" {
  description = "Endpoint execute-api de la HTTP API (solo responde con la cabecera x-origin-verify de CloudFront)."
  value       = module.api.api_endpoint
}

output "api_function_name" {
  description = "Nombre de la Lambda de la API (el pipeline de la aplicación publica versiones nuevas)."
  value       = module.api_function.function_name
}

output "api_function_role_name" {
  description = "Rol de ejecución de la Lambda, para añadir permisos de la aplicación desde fuera."
  value       = module.api_function.role_name
}

output "user_pool_id" {
  description = "ID del user pool de clientes."
  value       = module.customers.user_pool_id
}

output "user_pool_client_ids" {
  description = "IDs de los app clients (configuración del frontend)."
  value       = module.customers.client_ids
}

output "issuer_url" {
  description = "Emisor de los JWT (validación en la aplicación)."
  value       = module.customers.issuer_url
}

output "event_bus_name" {
  description = "Bus de eventos de dominio (orders.*)."
  value       = module.events.bus_name
}

output "table_name" {
  description = "Tabla DynamoDB de la tienda; null con aurora_data_api."
  value       = try(module.table[0].table_name, null)
}

output "aurora_cluster_arn" {
  description = "ARN del cluster Aurora (resourceArn de la Data API); null con dynamodb."
  value       = try(module.aurora[0].cluster_arn, null)
}

output "aurora_app_secret_arn" {
  description = "Secreto app_runtime (secretArn de la Data API); null con dynamodb."
  value       = try(module.aurora[0].app_secret_arn, null)
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
