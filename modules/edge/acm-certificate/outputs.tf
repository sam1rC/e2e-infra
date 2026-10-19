output "certificate_arn" {
  description = "ARN del certificado. Con validación activa solo se devuelve cuando el certificado ya está emitido."
  value       = local.validate ? aws_acm_certificate_validation.this[0].certificate_arn : aws_acm_certificate.this.arn
}

output "validation_records" {
  description = "Registros DNS de validación por dominio (para crear a mano si el DNS no está en Route 53)."
  value = {
    for o in aws_acm_certificate.this.domain_validation_options : o.domain_name => {
      name  = o.resource_record_name
      type  = o.resource_record_type
      value = o.resource_record_value
    }
  }
}

output "domain_name" {
  description = "Dominio principal del certificado."
  value       = var.domain_name
}
