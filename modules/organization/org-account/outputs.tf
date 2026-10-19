output "account_id" {
  description = "ID de la cuenta (12 dígitos): allowed_account_ids y assume_role de las composiciones de live/."
  value       = aws_organizations_account.this.id
}

output "account_arn" {
  description = "ARN de la cuenta en la organización."
  value       = aws_organizations_account.this.arn
}

output "account_name" {
  description = "Nombre de la cuenta."
  value       = aws_organizations_account.this.name
}

output "bootstrap_role_arn" {
  description = "Rol de administración que crea Organizations en la cuenta (solo bootstrap: account-baseline y roles de despliegue)."
  value       = "arn:${data.aws_partition.current.partition}:iam::${aws_organizations_account.this.id}:role/${var.role_name}"
}
