output "plan_role_arn" {
  description = "ARN del rol de plan (usar en configure-aws-credentials de los jobs de plan)."
  value       = aws_iam_role.plan.arn
}

output "apply_role_arn" {
  description = "ARN del rol de apply (usar solo en jobs con environment: <env>)."
  value       = aws_iam_role.apply.arn
}

output "apply_boundary_policy_arn" {
  description = "ARN de la permission boundary del rol de apply."
  value       = aws_iam_policy.apply_boundary.arn
}

output "oidc_provider_arn" {
  description = "ARN del proveedor OIDC de GitHub usado por los roles."
  value       = local.provider_arn
}
