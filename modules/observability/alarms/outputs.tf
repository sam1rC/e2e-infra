output "topic_arn" {
  description = "ARN del topic de alarmas (el creado, cifrado con la CMK, o existing_topic_arn). Úsalo como destino de otras alarmas o reglas de este entorno (alarm_actions)."
  value       = local.topic_arn
}

output "alarm_arns" {
  description = "ARN de todas las alarmas creadas, por nombre lógico (para el widget de estado del dashboard)."
  value = merge(
    { for k, a in aws_cloudwatch_metric_alarm.simple : k => a.arn },
    { for k, a in aws_cloudwatch_metric_alarm.dynamodb : k => a.arn },
    { for k, a in aws_cloudwatch_metric_alarm.waf_anomaly : "waf-${k}-blocked-anomaly" => a.arn },
  )
}

output "alarm_count" {
  description = "Número de alarmas creadas."
  value       = length(aws_cloudwatch_metric_alarm.simple) + length(aws_cloudwatch_metric_alarm.dynamodb) + length(aws_cloudwatch_metric_alarm.waf_anomaly)
}
