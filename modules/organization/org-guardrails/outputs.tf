output "security_policy_id" {
  description = "ID de la SCP de seguridad."
  value       = aws_organizations_policy.security.id
}

output "region_policy_id" {
  description = "ID de la SCP de restricción de regiones."
  value       = aws_organizations_policy.region.id
}

output "rcp_policy_id" {
  description = "ID de la RCP (null si no está habilitada)."
  value       = one(aws_organizations_policy.rcp[*].id)
}
