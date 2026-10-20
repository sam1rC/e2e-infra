provider "aws" {
  region = "us-east-1"
}

variable "domain_name" {
  description = "Dominio público de la aplicación (debe estar cubierto por el certificado)."
  type        = string
  default     = "app.example.com"
  nullable    = false
}

variable "certificate_arn" {
  description = "Certificado ACM EMITIDO en us-east-1, usado en CloudFront y en el listener del ALB (misma región en este ejemplo)."
  type        = string
  default     = "arn:aws:acm:us-east-1:123456789012:certificate/11111111-2222-3333-4444-555555555555"
  nullable    = false
}

module "vpc" {
  source = "../../../../network/vpc"

  project     = "acme"
  environment = "dev"
  cidr_block  = "10.20.0.0/16"
  az_names    = ["us-east-1a", "us-east-1b"]

  nat_mode         = "none"
  enable_flow_logs = false # solo para el ejemplo
}

resource "aws_security_group" "alb" {
  name_prefix = "acme-dev-alb-"
  description = "ALB interno del ejemplo: la entrada la anade el modulo de CloudFront"
  vpc_id      = module.vpc.vpc_id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb" "this" {
  name                       = "acme-dev-example"
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

module "security_headers" {
  source = "../../../security-headers"

  project     = "acme"
  environment = "dev"
}

module "cloudfront" {
  source = "../.."

  project     = "acme"
  environment = "dev"

  vpc_id                     = module.vpc.vpc_id
  alb_arn                    = aws_lb.this.arn
  alb_dns_name               = aws_lb.this.dns_name
  alb_security_group_id      = aws_security_group.alb.id
  domain_names               = [var.domain_name]
  acm_certificate_arn        = var.certificate_arn
  response_headers_policy_id = module.security_headers.policy_id

  depends_on = [aws_lb_listener.https]
}

output "distribution_domain_name" {
  description = "Dominio de la distribución."
  value       = module.cloudfront.distribution_domain_name
}
