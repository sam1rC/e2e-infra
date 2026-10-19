output "aurora_cluster_id" {
  description = "Identificador del cluster Aurora."
  value       = module.data.aurora_cluster_id
}

output "aurora_writer_endpoint" {
  description = "Endpoint del writer (privado)."
  value       = module.data.aurora_writer_endpoint
}

output "aurora_security_group_id" {
  description = "Security group de Aurora (la capa app añade la entrada desde las tareas)."
  value       = module.data.aurora_security_group_id
}

output "app_secret_arn" {
  description = "Secreto app_runtime que lee la aplicación."
  value       = module.data.app_secret_arn
}

output "master_user_secret_arn" {
  description = "Secreto maestro gestionado por RDS (solo administración y migraciones, p. ej. sql/)."
  value       = module.data.master_user_secret_arn
}

output "cache_replication_group_id" {
  description = "Replication group de Valkey (host que firma el token IAM); null sin caché."
  value       = module.data.cache_replication_group_id
}

output "kms_key_arn" {
  description = "CMK de datos."
  value       = module.data.kms_key_arn
}

output "backup_vault_names" {
  description = "Vaults de AWS Backup: principal y de DR (null sin copia)."
  value       = module.data.backup_vault_names
}
