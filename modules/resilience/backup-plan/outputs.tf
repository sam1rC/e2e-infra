output "vault_arn" {
  description = "ARN del vault: es el destino de copy_destinations del vault de origen."
  value       = aws_backup_vault.this.arn
}

output "vault_name" {
  description = "Nombre del vault."
  value       = aws_backup_vault.this.name
}

output "plan_id" {
  description = "ID del plan de backup; null si plan_enabled = false."
  value       = var.plan_enabled ? aws_backup_plan.this[0].id : null
}

output "plan_arn" {
  description = "ARN del plan de backup; null si plan_enabled = false."
  value       = var.plan_enabled ? aws_backup_plan.this[0].arn : null
}

output "service_role_arn" {
  description = "Rol de servicio de AWS Backup; null si plan_enabled = false."
  value       = var.plan_enabled ? aws_iam_role.backup[0].arn : null
}

output "restore_testing_plan_arn" {
  description = "ARN del plan de pruebas de restauración; null si restore_testing no está configurado."
  value       = var.restore_testing == null ? null : aws_backup_restore_testing_plan.this[0].arn
}
