output "api_id" {
  description = "ID de la HTTP API."
  value       = aws_apigatewayv2_api.this.id
}

output "api_endpoint" {
  description = "Endpoint por defecto (https://<id>.execute-api.<región>.amazonaws.com)."
  value       = aws_apigatewayv2_api.this.api_endpoint
}

output "origin_domain_name" {
  description = "Dominio para el origen /api/* de edge/cloudfront-static-site (con AllViewerExceptHostHeader: el endpoint tiene certificado de AWS para su propio nombre)."
  value       = trimprefix(aws_apigatewayv2_api.this.api_endpoint, "https://")
}

output "execution_arn" {
  description = "ARN de ejecución (base de las condiciones source_arn de los permisos de Lambda)."
  value       = aws_apigatewayv2_api.this.execution_arn
}

output "stage_name" {
  description = "Nombre de la etapa ($default, desplegada automáticamente)."
  value       = aws_apigatewayv2_stage.this.name
}

output "authorizer_id" {
  description = "ID del autorizador JWT; null si no hay."
  value       = try(aws_apigatewayv2_authorizer.jwt[0].id, null)
}

output "access_log_group_name" {
  description = "Log group de los logs de acceso."
  value       = aws_cloudwatch_log_group.access.name
}
