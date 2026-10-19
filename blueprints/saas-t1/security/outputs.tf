output "ou_ids" {
  description = "ID de cada OU (security, infrastructure, nonprod, prod, silo)."
  value       = local.ou_ids
}

output "account_ids" {
  description = "ID de cada cuenta miembro, por clave (allowed_account_ids de las composiciones de live/)."
  value       = { for k, a in module.accounts : k => a.account_id }
}

output "bootstrap_role_arns" {
  description = "Rol de bootstrap de cada cuenta (aplicar account-baseline y los roles de despliegue; después, IAM Identity Center)."
  value       = { for k, a in module.accounts : k => a.bootstrap_role_arn }
}

output "silo_account_ids" {
  description = "Cuentas silo por tenant_id (las usa el control plane para desplegar la infraestructura dedicada)."
  value       = { for k, a in var.accounts : a.tenant_id => module.accounts[k].account_id if a.tenant_id != null }
}

output "security_account_id" {
  description = "Cuenta de administración delegada de los servicios de seguridad."
  value       = local.security_account_id
}
