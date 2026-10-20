output "bus_name" {
  description = "Nombre del bus: es el valor de EventBusName en events:PutEvents."
  value       = aws_cloudwatch_event_bus.this.name
}

output "bus_arn" {
  description = "ARN del bus. Úsalo en la política IAM de los publicadores (events:PutEvents)."
  value       = aws_cloudwatch_event_bus.this.arn
}

output "rule_arns" {
  description = "ARN de cada regla, por clave."
  value       = { for k, r in aws_cloudwatch_event_rule.this : k => r.arn }
}

output "dlq_arns" {
  description = "ARN de la DLQ de cada regla, por clave."
  value       = { for k, q in aws_sqs_queue.dlq : k => q.arn }
}

output "dlq_names" {
  description = "Nombre de la DLQ de cada regla, por clave (dimensión QueueName de las alarmas de mensajes visibles)."
  value       = { for k, q in aws_sqs_queue.dlq : k => q.name }
}

output "archive_arn" {
  description = "ARN del archivo para replay; null si el archivo está desactivado."
  value       = var.archive_retention_days > 0 ? aws_cloudwatch_event_archive.this[0].arn : null
}
