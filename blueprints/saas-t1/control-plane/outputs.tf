output "user_pools" {
  description = "User pools por clave (tier o tenant): ID, ARN, emisor de los JWT y app client web. El app plane recibe los emisores como variable (jwt_issuers)."
  value = {
    for k, p in module.pools : k => {
      user_pool_id  = p.user_pool_id
      user_pool_arn = p.user_pool_arn
      issuer_url    = p.issuer_url
      client_id     = p.client_ids["web"]
    }
  }
}

output "issuers" {
  description = "Emisores de JWT aceptados por el app plane."
  value       = [for p in module.pools : p.issuer_url]
}

output "event_bus_arn" {
  description = "Bus del control plane: el app plane publica aquí los eventos de uso (metering_bus_arn de app-app)."
  value       = module.events.bus_arn
}

output "registry_table_name" {
  description = "Tabla del registro de tenants."
  value       = module.registry.table_name
}

output "onboarding_function_name" {
  description = "Lambda de onboarding."
  value       = module.onboarding.function_name
}

output "metering_bucket_id" {
  description = "Bucket de metering (usage/tenant_id=<id>/yyyy/MM/dd/)."
  value       = module.metering_bucket.bucket_id
}

output "github_app_secret_arn" {
  description = "Secreto donde cargar a mano la clave privada de la GitHub App; null sin pipeline de silos."
  value       = try(aws_secretsmanager_secret.github_app[0].arn, null)
}
