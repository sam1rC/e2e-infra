output "distribution_id" {
  description = "ID de la distribución."
  value       = module.cdn.distribution_id
}

output "distribution_domain_name" {
  description = "Dominio *.cloudfront.net (destino del CNAME si el DNS es externo)."
  value       = module.cdn.distribution_domain_name
}

output "web_acl_arn" {
  description = "Web ACL de CloudFront."
  value       = module.waf.web_acl_arn
}

output "alarm_topic_arn" {
  description = "Topic de alarmas de borde (us-east-1)."
  value       = module.alarms.topic_arn
}
