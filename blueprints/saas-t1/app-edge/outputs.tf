output "distribution_id" {
  description = "ID de la distribución."
  value       = module.edge.distribution_id
}

output "distribution_domain_name" {
  description = "Dominio *.cloudfront.net (destino del CNAME si el DNS es externo)."
  value       = module.edge.distribution_domain_name
}

output "web_acl_arn" {
  description = "Web ACL de CloudFront."
  value       = module.edge.web_acl_arn
}

output "alarm_topic_arn" {
  description = "Topic de alarmas de borde (us-east-1)."
  value       = module.edge.alarm_topic_arn
}
