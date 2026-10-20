output "kms_key_arn" {
  description = "ARN de la CMK de la línea base (logs, alertas y EBS por defecto)."
  value       = module.kms.key_arn
}

output "log_bucket_name" {
  description = "Bucket que recibe los logs de CloudTrail y Config (local o externo)."
  value       = local.log_bucket_name
}

output "trail_arn" {
  description = "ARN del trail multi-región."
  value       = aws_cloudtrail.this.arn
}

output "alerts_topic_arn" {
  description = "ARN del tópico SNS cifrado de alertas de seguridad."
  value       = aws_sns_topic.alerts.arn
}

output "guardduty_detector_id" {
  description = "ID del detector de GuardDuty."
  value       = aws_guardduty_detector.this.id
}
