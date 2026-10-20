output "role_arn" {
  description = "ARN del rol de acceso del tenant: la aplicación lo pasa a AssumeRole con Tags=[{Key=<tenant_tag_key>, Value=<tenant del JWT>}]."
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Nombre del rol."
  value       = aws_iam_role.this.name
}

output "tenant_tag_key" {
  description = "Clave de la etiqueta de sesión (y del contexto de cifrado KMS) que debe usar la aplicación."
  value       = var.tenant_tag_key
}

output "assume_role_policy_json" {
  description = "Trust policy del rol (para revisión y auditoría)."
  value       = data.aws_iam_policy_document.trust.json
}

output "permissions_policy_json" {
  description = "Política de permisos del rol (para revisión y auditoría)."
  value       = data.aws_iam_policy_document.permissions.json
}
