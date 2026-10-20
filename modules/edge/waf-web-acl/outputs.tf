output "web_acl_arn" {
  description = "ARN del Web ACL (null si create_web_acl = false)."
  value       = one(aws_wafv2_web_acl.this[*].arn)
}

output "web_acl_id" {
  description = "ID del Web ACL (null si create_web_acl = false)."
  value       = one(aws_wafv2_web_acl.this[*].id)
}

output "web_acl_name" {
  description = "Nombre del Web ACL (null si create_web_acl = false)."
  value       = one(aws_wafv2_web_acl.this[*].name)
}

output "log_group_name" {
  description = "Grupo de CloudWatch Logs con los logs del WAF (null si create_web_acl = false)."
  value       = one(aws_cloudwatch_log_group.waf[*].name)
}
