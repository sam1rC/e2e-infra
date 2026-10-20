output "role_arn" {
  description = "ARN del rol (role_arn del assume_role del provider en la cuenta de origen)."
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Nombre del rol."
  value       = aws_iam_role.this.name
}

output "assume_role_policy_json" {
  description = "Trust policy del rol (para revisión y auditoría)."
  value       = data.aws_iam_policy_document.trust.json
}
