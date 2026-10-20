# Instanciar con el provider aws.us_east_1 para CloudFront y con el provider regional para el ALB:
#   providers = { aws = aws.us_east_1 }
resource "aws_acm_certificate" "this" {
  domain_name               = var.domain_name
  subject_alternative_names = var.subject_alternative_names
  validation_method         = "DNS"
  key_algorithm             = var.key_algorithm

  tags = merge(var.tags, { Name = "${var.project}-${var.environment}-${var.domain_name}" })

  lifecycle {
    create_before_destroy = true
  }
}

# Se itera sobre los dominios de entrada (claves conocidas al planificar) y se busca su opción de
# validación: domain_validation_options solo se conoce tras crear el certificado. allow_overwrite
# cubre el caso de example.com y *.example.com, que comparten el mismo registro CNAME.
resource "aws_route53_record" "validation" {
  for_each = local.create_records ? toset(local.domains) : toset([])

  zone_id         = var.zone_id
  allow_overwrite = true
  ttl             = 60
  name            = [for o in aws_acm_certificate.this.domain_validation_options : o.resource_record_name if o.domain_name == each.key][0]
  type            = [for o in aws_acm_certificate.this.domain_validation_options : o.resource_record_type if o.domain_name == each.key][0]
  records         = [[for o in aws_acm_certificate.this.domain_validation_options : o.resource_record_value if o.domain_name == each.key][0]]
}

resource "aws_acm_certificate_validation" "this" {
  count = local.validate ? 1 : 0

  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = local.create_records ? [for r in aws_route53_record.validation : r.fqdn] : null
}
