output "alb_arn" {
  description = "ARN del ALB interno."
  value       = aws_lb.this.arn
}

output "alb_arn_suffix" {
  description = "Sufijo del ARN del ALB (dimensión LoadBalancer de las métricas de CloudWatch y del ALBRequestCountPerTarget)."
  value       = aws_lb.this.arn_suffix
}

output "alb_dns_name" {
  description = "Nombre DNS del ALB; resuelve solo a IPs privadas."
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "Zona hospedada canónica del ALB."
  value       = aws_lb.this.zone_id
}

output "security_group_id" {
  description = "Security group del ALB. El módulo de edge añade la regla de entrada desde CloudFront; los targets la usan como origen permitido."
  value       = aws_security_group.this.id
}

output "https_listener_arn" {
  description = "ARN del listener HTTPS (443)."
  value       = aws_lb_listener.https.arn
}

output "target_group_arns" {
  description = "ARN de cada target group, por clave."
  value       = { for k, tg in aws_lb_target_group.this : k => tg.arn }
}

output "target_group_arn_suffixes" {
  description = "Sufijo del ARN de cada target group, por clave (dimensión TargetGroup de las métricas y de ALBRequestCountPerTarget)."
  value       = { for k, tg in aws_lb_target_group.this : k => tg.arn_suffix }
}
