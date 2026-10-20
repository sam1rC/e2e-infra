output "rule_group_id" {
  description = "ID del grupo de reglas del DNS Firewall."
  value       = aws_route53_resolver_firewall_rule_group.this.id
}

output "rule_group_arn" {
  description = "ARN del grupo de reglas del DNS Firewall."
  value       = aws_route53_resolver_firewall_rule_group.this.arn
}

output "query_log_config_id" {
  description = "ID de la configuración de logs de consultas DNS."
  value       = aws_route53_resolver_query_log_config.this.id
}
