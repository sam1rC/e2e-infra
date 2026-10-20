output "tenant_kms_key_arn" {
  description = "CMK dedicada del tenant."
  value       = module.tenant_kms.key_arn
}

output "deploy_role_arn" {
  description = "Rol que asume el pipeline del control plane para desplegar las capas del tenant."
  value       = module.deploy_role.role_arn
}

output "budget_name" {
  description = "Presupuesto mensual de la cuenta del tenant."
  value       = module.budget.budget_name
}
