output "bucket_id" {
  description = "Nombre del bucket donde el pipeline sube el sitio."
  value       = module.bucket.bucket_id
}

output "bucket_arn" {
  description = "ARN del bucket del sitio."
  value       = module.bucket.bucket_arn
}

output "kms_key_arn" {
  description = "ARN de la CMK del bucket (propia o la aportada). El pipeline de despliegue necesita kms:GenerateDataKey/Encrypt sobre ella."
  value       = local.kms_key_arn
}

output "distribution_id" {
  description = "ID de la distribución (para invalidaciones tras desplegar)."
  value       = aws_cloudfront_distribution.this.id
}

output "distribution_arn" {
  description = "ARN de la distribución."
  value       = aws_cloudfront_distribution.this.arn
}

output "distribution_domain_name" {
  description = "Dominio *.cloudfront.net de la distribución."
  value       = aws_cloudfront_distribution.this.domain_name
}

output "cloudfront_read_policy_statement" {
  description = "Declaración de la política del bucket que da lectura a la distribución (OAC), para auditoría."
  value       = local.cloudfront_read_statement
}
