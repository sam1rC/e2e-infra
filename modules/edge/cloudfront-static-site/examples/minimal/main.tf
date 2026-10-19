provider "aws" {
  region = "us-east-1"
}

variable "certificate_arn" {
  description = "Certificado ACM EMITIDO en us-east-1 que cubre el dominio."
  type        = string
  default     = "arn:aws:acm:us-east-1:123456789012:certificate/11111111-2222-3333-4444-555555555555"
  nullable    = false
}

module "security_headers" {
  source = "../../../security-headers"

  project     = "acme"
  environment = "dev"
}

module "site" {
  source = "../.."

  project                    = "acme"
  environment                = "dev"
  domain_names               = ["www.example.com"]
  acm_certificate_arn        = var.certificate_arn
  response_headers_policy_id = module.security_headers.policy_id
}

output "bucket_id" {
  description = "Bucket del sitio."
  value       = module.site.bucket_id
}
