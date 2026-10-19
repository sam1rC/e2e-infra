output "function_name" {
  description = "Nombre de la función."
  value       = aws_lambda_function.this.function_name
}

output "function_arn" {
  description = "ARN de la función."
  value       = aws_lambda_function.this.arn
}

output "invoke_arn" {
  description = "ARN de invocación (para integraciones de API Gateway)."
  value       = aws_lambda_function.this.invoke_arn
}

output "role_arn" {
  description = "ARN del rol de ejecución."
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Nombre del rol de ejecución, para adjuntar políticas desde fuera del módulo."
  value       = aws_iam_role.this.name
}

output "log_group_name" {
  description = "Nombre del log group de la función."
  value       = aws_cloudwatch_log_group.this.name
}

output "security_group_id" {
  description = "Security group de la función (null si no está en la VPC). Añádelo a los orígenes permitidos de la base de datos o los endpoints."
  value       = one(aws_security_group.this[*].id)
}

output "dlq_arn" {
  description = "ARN de la cola de dead-letter (null si enable_dlq es false)."
  value       = one(aws_sqs_queue.dlq[*].arn)
}
