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
  description = "Dominio público de la aplicación (debe estar cubierto por el certificado)."
  type        = string
  default     = "app.example.com"
  nullable    = false
}

variable "certificate_arn" {
  description = "Certificado ACM EMITIDO en us-east-1, usado en CloudFront y en el listener del ALB (misma región en este ejemplo). El sandbox debe tener una zona delegada para emitirlo (ver runbook de validación DNS)."
  type        = string
  default     = "arn:aws:acm:us-east-1:123456789012:certificate/11111111-2222-3333-4444-555555555555"
  nullable    = false
}

variable "zone_id" {
  description = "Zona de Route 53 de pruebas para los alias. null = sin DNS."
  type        = string
  default     = null
}

data "aws_caller_identity" "current" {}

module "vpc" {
  source = "../../../../network/vpc"

  project     = "acme-${var.name_suffix}"
  environment = "dev"
  cidr_block  = "10.50.0.0/16"
  az_names    = ["us-east-1a", "us-east-1b"]

  nat_mode               = "regional"
  enable_flow_logs       = false # el bucket de flow logs se prueba en el ejemplo de vpc
  publish_ssm_parameters = false
}

resource "aws_security_group" "alb" {
  name_prefix = "acme-${var.name_suffix}-alb-"
  description = "ALB interno del ejemplo: la entrada la anade el modulo de CloudFront"
  vpc_id      = module.vpc.vpc_id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb" "this" {
  name                       = substr("acme-${var.name_suffix}", 0, 32)
  internal                   = true
  load_balancer_type         = "application"
  subnets                    = module.vpc.subnet_ids["app"]
  security_groups            = [aws_security_group.alb.id]
  drop_invalid_header_fields = true
  desync_mitigation_mode     = "strictest"
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "ok"
      status_code  = "200"
    }
  }
}

# Bucket de logs de acceso de CloudFront (logging v2: sin ACL; SSE-S3).
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

  content_security_policy = "default-src 'self'; frame-ancestors 'none'"
}

module "cloudfront" {
  source = "../.."

  project     = "acme-${var.name_suffix}"
  environment = "dev"

  vpc_id                      = module.vpc.vpc_id
  alb_arn                     = aws_lb.this.arn
  alb_dns_name                = aws_lb.this.dns_name
  alb_security_group_id       = aws_security_group.alb.id
  alb_ingress_source          = "cloudfront_managed_sg"
  domain_names                = [var.domain_name]
  acm_certificate_arn         = var.certificate_arn
  web_acl_arn                 = module.waf.web_acl_arn
  response_headers_policy_id  = module.security_headers.policy_id
  static_path_patterns        = ["/static/*", "/assets/*"]
  price_class                 = "PriceClass_100"
  origin_read_timeout_seconds = 30
  zone_id                     = var.zone_id
  log_bucket_arn              = module.logs_bucket.bucket_arn
  access_logs_enabled         = true # el bucket se crea en este mismo apply
  log_prefix                  = "cloudfront"

  tags = {
    Owner = "platform"
  }

  depends_on = [aws_lb_listener.https]
}

output "distribution_domain_name" {
  description = "Dominio de la distribución."
  value       = module.cloudfront.distribution_domain_name
}

output "distribution_id" {
  description = "ID de la distribución."
  value       = module.cloudfront.distribution_id
}
