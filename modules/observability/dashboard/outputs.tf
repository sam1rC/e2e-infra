output "dashboard_name" {
  description = "Nombre del dashboard."
  value       = aws_cloudwatch_dashboard.this.dashboard_name
}

output "dashboard_arn" {
  description = "ARN del dashboard."
  value       = aws_cloudwatch_dashboard.this.dashboard_arn
}

output "widget_count" {
  description = "Número de widgets del dashboard (el límite de CloudWatch es 500)."
  value       = length(local.widgets)
}
