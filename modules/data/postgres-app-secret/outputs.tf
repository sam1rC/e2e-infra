output "secret_arn" {
  description = "ARN del secreto de la aplicación (app_runtime). Las tareas ECS lo leen con `secrets`; el execution role necesita GetSecretValue sobre este ARN y kms:Decrypt vía Secrets Manager."
  value       = aws_secretsmanager_secret.app_runtime.arn
}

output "secret_name" {
  description = "Nombre del secreto de la aplicación."
  value       = aws_secretsmanager_secret.app_runtime.name
}

output "rotation_lambda_arn" {
  description = "ARN de la función de rotación; null si no hay rotación."
  value       = local.rotation_enabled ? aws_cloudformation_stack.rotation[0].outputs["RotationLambdaARN"] : null
}

output "rotation_security_group_id" {
  description = "Security group de la función de rotación; null si no hay rotación."
  value       = local.rotation_enabled ? aws_security_group.rotation[0].id : null
}
