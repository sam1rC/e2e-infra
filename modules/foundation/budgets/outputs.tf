output "budget_name" {
  description = "Nombre del presupuesto mensual."
  value       = aws_budgets_budget.monthly.name
}

output "anomaly_monitor_arn" {
  description = "ARN del monitor de anomalías de costo (el creado o el existente)."
  value       = local.anomaly_monitor_arn
}
