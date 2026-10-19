output "rest_api_id" {
  description = "ID de la REST API."
  value       = aws_api_gateway_rest_api.this.id
}

output "execution_arn" {
  description = "ARN de ejecución de la API."
  value       = aws_api_gateway_rest_api.this.execution_arn
}

output "stage_name" {
  description = "Nombre de la etapa."
  value       = aws_api_gateway_stage.this.stage_name
}

output "stage_arn" {
  description = "ARN de la etapa (recurso al que se asocia el WAF regional)."
  value       = aws_api_gateway_stage.this.arn
}

output "invoke_url" {
  description = "URL de la etapa (https://<id>.execute-api.<región>.amazonaws.com/<etapa>)."
  value       = aws_api_gateway_stage.this.invoke_url
}

output "origin_domain_name" {
  description = "Dominio para el origen /api/* de edge/cloudfront-static-site (con AllViewerExceptHostHeader y endpoint_access_mode STRICT)."
  value       = "${aws_api_gateway_rest_api.this.id}.execute-api.${data.aws_region.current.region}.amazonaws.com"
}

output "origin_path" {
  description = "origin_path del origen de CloudFront (/<etapa>)."
  value       = "/${var.stage_name}"
}

output "authorizer_id" {
  description = "ID del autorizador de Cognito."
  value       = aws_api_gateway_authorizer.cognito.id
}

output "usage_plan_ids" {
  description = "ID de cada plan de uso por tier: el onboarding asocia la API key del tenant al plan de su tier (aws apigateway create-usage-plan-key)."
  value       = { for k, p in aws_api_gateway_usage_plan.this : k => p.id }
}

output "access_log_group_name" {
  description = "Log group de los logs de acceso."
  value       = aws_cloudwatch_log_group.access.name
}
