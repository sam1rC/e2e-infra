output "repository_url" {
  description = "URL del repositorio (<cuenta>.dkr.ecr.<región>.amazonaws.com/<nombre>). La imagen se referencia por digest: <url>@sha256:..."
  value       = aws_ecr_repository.this.repository_url
}

output "repository_arn" {
  description = "ARN del repositorio (para políticas IAM de pull/push)."
  value       = aws_ecr_repository.this.arn
}

output "repository_name" {
  description = "Nombre del repositorio."
  value       = aws_ecr_repository.this.name
}

output "registry_id" {
  description = "ID del registro (cuenta propietaria)."
  value       = aws_ecr_repository.this.registry_id
}
