locals {
  project = "ct-${var.name_suffix}"

  tags = {
    Project            = local.project
    Environment        = "test"
    Owner              = "platform"
    ManagedBy          = "opentofu"
    Blueprint          = "ecommerce-t2"
    CostCenter         = "catalog-test"
    DataClassification = "internal"
    TTL                = "4h"
    RunId              = var.run_id
  }
}

provider "aws" {
  region              = var.region
  allowed_account_ids = [var.account_id]

  default_tags {
    tags = local.tags
  }
}

provider "aws" {
  alias               = "us_east_1"
  region              = "us-east-1"
  allowed_account_ids = [var.account_id]

  default_tags {
    tags = local.tags
  }
}

module "edge" {
  source = "../../../edge"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  project     = local.project
  environment = "dev"

  domain_name  = var.domain_name
  zone_id      = var.zone_id
  alarm_emails = var.alarm_emails

  # En dev el WAF va en count; la prueba bloquea para comprobar el 403 de una SQLi.
  waf = { rules_mode = "block" }
}

output "distribution_domain_name" {
  description = "Dominio de CloudFront."
  value       = module.edge.distribution_domain_name
}

output "url" {
  description = "URL pública."
  value       = "https://${var.domain_name}"
}
