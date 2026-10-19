output "table_name" {
  description = "Nombre real de la tabla."
  value       = aws_dynamodb_table.this.name
}

output "table_arn" {
  description = "ARN de la tabla."
  value       = aws_dynamodb_table.this.arn
}

output "index_arns" {
  description = "ARN de cada índice secundario (global o local), por nombre."
  value = {
    for n in sort(concat(keys(var.global_secondary_indexes), keys(var.local_secondary_indexes))) :
    n => "${aws_dynamodb_table.this.arn}/index/${n}"
  }
}

output "iam_resource_arns" {
  description = "Recursos para las políticas IAM de la aplicación: la tabla y todos sus índices. Con tenant_partition_key, combínalos con la condición dynamodb:LeadingKeys."
  value       = [aws_dynamodb_table.this.arn, "${aws_dynamodb_table.this.arn}/index/*"]
}

output "stream_arn" {
  description = "ARN del stream; null si los streams están desactivados."
  value       = var.stream_view_type == null ? null : aws_dynamodb_table.this.stream_arn
}
