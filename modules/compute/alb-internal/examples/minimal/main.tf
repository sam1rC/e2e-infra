provider "aws" {
  region = "us-east-1"
}

variable "certificate_arn" {
  description = "Certificado ACM EMITIDO en la región del ALB, del dominio público de la aplicación."
  type        = string
  default     = "arn:aws:acm:us-east-1:123456789012:certificate/11111111-2222-3333-4444-555555555555"
  nullable    = false
}

module "vpc" {
  source = "../../../../network/vpc"

  project     = "acme"
  environment = "dev"
  cidr_block  = "10.60.0.0/16"
  az_names    = ["us-east-1a", "us-east-1b"]

  nat_mode         = "none"
  enable_flow_logs = false # solo para el ejemplo
}

module "alb" {
  source = "../.."

  project         = "acme"
  environment     = "dev"
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.subnet_ids["app"]
  certificate_arn = var.certificate_arn

  target_groups = {
    web = { port = 8080 }
  }

  listener_rules = {
    app = {
      priority     = 10
      target_group = "web"
      host_headers = ["app.example.com"]
    }
  }
}

output "alb_dns_name" {
  description = "DNS interno del ALB."
  value       = module.alb.alb_dns_name
}
