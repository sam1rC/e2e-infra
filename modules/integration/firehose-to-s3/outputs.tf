output "delivery_stream_arn" {
  description = "ARN del delivery stream: es el firehose_arn de las reglas de eventbridge-bus."
  value       = aws_kinesis_firehose_delivery_stream.this.arn
}

output "delivery_stream_name" {
  description = "Nombre del delivery stream (dimensión DeliveryStreamName de las métricas de CloudWatch)."
  value       = aws_kinesis_firehose_delivery_stream.this.name
}

output "role_arn" {
  description = "Rol de entrega del stream."
  value       = aws_iam_role.this.arn
}

output "log_group_name" {
  description = "Log group de los errores de entrega."
  value       = aws_cloudwatch_log_group.this.name
}

output "object_prefix" {
  description = "Prefijo de los objetos en S3 (con las expresiones de partición de Firehose)."
  value       = local.prefix
}
