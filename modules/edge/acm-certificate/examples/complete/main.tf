provider "aws" {
  region = "us-east-1"
}

# CloudFront exige el certificado en us-east-1; el del ALB va en la región del balanceador.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

variable "name_suffix" {
  description = "Sufijo para el nombre de la zona de pruebas (evita colisiones en ejecuciones paralelas)."
  type        = string
  default     = "example"
  nullable    = false
}

# Zona de pruebas: sin delegación real, así que la validación no puede completarse;
# el ejemplo comprueba la creación del certificado y de los registros.
resource "aws_route53_zone" "test" {
  name = "acm-${var.name_suffix}.example.com"
}

module "certificate_viewer" {
  source = "../.."

  providers = { aws = aws.us_east_1 }

  project                   = "acme-${var.name_suffix}"
  environment               = "dev"
  domain_name               = "app.${aws_route53_zone.test.name}"
  subject_alternative_names = ["www.${aws_route53_zone.test.name}"]
  key_algorithm             = "EC_prime256v1"
  zone_id                   = aws_route53_zone.test.zone_id
  wait_for_validation       = false

  tags = {
    Owner = "platform"
  }
}

output "certificate_arn" {
  description = "ARN del certificado."
  value       = module.certificate_viewer.certificate_arn
}

output "validation_records" {
  description = "Registros de validación."
  value       = module.certificate_viewer.validation_records
}
