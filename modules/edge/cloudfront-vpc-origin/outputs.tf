output "distribution_id" {
  description = "ID de la distribución."
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

output "vpc_origin_id" {
  description = "ID del VPC origin."
  value       = aws_cloudfront_vpc_origin.this.id
}
