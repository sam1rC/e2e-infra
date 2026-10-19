output "instance_id" {
  description = "Identificador de la instancia PostgreSQL."
  value       = module.postgres.instance_id
}

output "endpoint" {
  description = "Endpoint de la instancia (privado)."
  value       = module.postgres.endpoint
}

output "security_group_id" {
  description = "Security group de la base de datos (la capa app añade la entrada desde las tareas)."
  value       = module.postgres.security_group_id
}

output "app_secret_arn" {
  description = "Secreto app_runtime que lee la aplicación."
  value       = module.postgres.app_secret_arn
}

output "master_user_secret_arn" {
  description = "Secreto maestro gestionado por RDS (solo administración y migraciones, p. ej. sql/)."
  value       = module.postgres.master_user_secret_arn
}

output "kms_key_arn" {
  description = "CMK de datos."
  value       = module.kms.key_arn
}

output "backup_vault_name" {
  description = "Vault de AWS Backup del entorno."
  value       = module.backup.vault_name
}
