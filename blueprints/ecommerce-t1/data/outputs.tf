output "aurora_cluster_id" {
  description = "Identificador del cluster Aurora."
  value       = module.aurora.cluster_id
}

output "aurora_writer_endpoint" {
  description = "Endpoint del writer (privado)."
  value       = module.aurora.writer_endpoint
}

output "aurora_security_group_id" {
  description = "Security group de Aurora (la capa app añade la entrada desde las tareas)."
  value       = module.aurora.security_group_id
}

output "app_secret_arn" {
  description = "Secreto app_runtime que lee la aplicación."
  value       = module.aurora.app_secret_arn
}

output "master_user_secret_arn" {
  description = "Secreto maestro gestionado por RDS (solo administración y migraciones, p. ej. sql/)."
  value       = module.aurora.master_user_secret_arn
}

output "cache_replication_group_id" {
  description = "Replication group de Valkey (host que firma el token IAM); null sin caché."
  value       = try(module.cache[0].replication_group_id, null)
}

output "kms_key_arn" {
  description = "CMK de datos."
  value       = module.kms.key_arn
}

output "backup_vault_names" {
  description = "Vaults de AWS Backup: principal y de DR (null sin copia)."
  value       = { primary = module.backup.vault_name, dr = try(module.dr_backup[0].vault_name, null) }
}
