output "backend_config" {
  description = "Bloque backend + encryption equivalente al backend.tf.migrate generado (comprobación)."
  value       = module.state_backend.backend_config
}

output "state_bucket_id" {
  description = "Bucket de estado."
  value       = module.state_backend.bucket_id
}

output "plan_role_arn" {
  description = "Rol de plan de GitHub Actions (secreto/variable AWS_PLAN_ROLE_ARN del entorno en GitHub)."
  value       = module.github_oidc.plan_role_arn
}

output "apply_role_arn" {
  description = "Rol de apply de GitHub Actions (variable AWS_APPLY_ROLE_ARN del GitHub Environment)."
  value       = module.github_oidc.apply_role_arn
}

output "apply_boundary_policy_arn" {
  description = "Permission boundary del rol de apply."
  value       = module.github_oidc.apply_boundary_policy_arn
}

output "artifacts_bucket_id" {
  description = "Bucket de artefactos de Lambda (null si no se crea)."
  value       = try(module.artifacts[0].bucket_id, null)
}
