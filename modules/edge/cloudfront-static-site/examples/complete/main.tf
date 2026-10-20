provider "aws" {
  region = "us-east-1"
}

variable "name_suffix" {
  description = "Sufijo para nombres de la prueba (evita colisiones en ejecuciones paralelas)."
  type        = string
  default     = "example"
  nullable    = false
}

variable "domain_name" {
  description = "Dominio público del sitio (debe estar cubierto por el certificado)."
  type        = string
  default     = "www.example.com"
  nullable    = false
}

variable "certificate_arn" {
  description = "Certificado ACM EMITIDO en us-east-1 que cubre el dominio."
  type        = string
  default     = "arn:aws:acm:us-east-1:123456789012:certificate/11111111-2222-3333-4444-555555555555"
  nullable    = false
}

variable "zone_id" {
  description = "Zona de Route 53 de pruebas para el alias. null = sin DNS."
  type        = string
  default     = null
}

data "aws_caller_identity" "current" {}

module "logs_bucket" {
  source = "../../../../storage/s3-bucket"

  project       = "acme-${var.name_suffix}"
  environment   = "dev"
  purpose       = "logs"
  sse_algorithm = "AES256"
  force_destroy = true # solo porque es un ejemplo efímero

  policy_statements = [
    {
      # CloudFront (logging v2) escribe en AWSLogs/<cuenta>/CloudFront/<log_prefix>/...; es la declaración que
      # CloudWatch Logs añadiría por su cuenta (y que OpenTofu borraría en el siguiente apply).
      sid            = "AWSLogDeliveryWrite"
      actions        = ["s3:PutObject"]
      resource_paths = ["/AWSLogs/${data.aws_caller_identity.current.account_id}/CloudFront/*"]
      principals     = [{ type = "Service", identifiers = ["delivery.logs.amazonaws.com"] }]
      conditions = [
        { test = "StringEquals", variable = "s3:x-amz-acl", values = ["bucket-owner-full-control"] },
        { test = "StringEquals", variable = "aws:SourceAccount", values = [data.aws_caller_identity.current.account_id] },
        { test = "ArnLike", variable = "aws:SourceArn", values = ["arn:aws:logs:us-east-1:${data.aws_caller_identity.current.account_id}:delivery-source:acme-${var.name_suffix}-dev-cloudfront"] },
      ]
    },
  ]
}

module "waf" {
  source = "../../../waf-web-acl"

  project     = "acme-${var.name_suffix}"
  environment = "dev"
  scope       = "CLOUDFRONT"

  managed_rules_mode = "count"
}

module "security_headers" {
  source = "../../../security-headers"

  project     = "acme-${var.name_suffix}"
  environment = "dev"

  content_security_policy = "default-src 'self'; connect-src 'self' https://*.execute-api.us-east-1.amazonaws.com; frame-ancestors 'none'"
}

module "site" {
  source = "../.."

  project                    = "acme-${var.name_suffix}"
  environment                = "dev"
  domain_names               = [var.domain_name]
  acm_certificate_arn        = var.certificate_arn
  web_acl_arn                = module.waf.web_acl_arn
  response_headers_policy_id = module.security_headers.policy_id
  force_destroy              = true # solo porque es un ejemplo efímero

  spa_error_codes = [403, 404]

  api = {
    domain_name  = "abc123.execute-api.us-east-1.amazonaws.com"
    path_pattern = "/api/*"
  }
  api_origin_verify_secret = "0123456789abcdef0123456789abcdef" # solo para el ejemplo; en real, secreto rotado

  price_class         = "PriceClass_100"
  zone_id             = var.zone_id
  log_bucket_arn      = module.logs_bucket.bucket_arn
  access_logs_enabled = true # el bucket se crea en este mismo apply
  log_prefix          = "cloudfront"

  tags = {
    Owner = "platform"
  }
}

output "distribution_domain_name" {
  description = "Dominio de la distribución."
  value       = module.site.distribution_domain_name
}

output "bucket_id" {
  description = "Bucket del sitio."
  value       = module.site.bucket_id
}
