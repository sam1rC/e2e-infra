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

module "app" {
  source = "../../../app"

  project     = local.project
  environment = "dev"

  domain_name = var.domain_name
  zone_id     = var.zone_id

  # La imagen de prueba es pública (public.ecr.aws): las tareas la descargan por la NAT.
  allow_internet_egress = true

  service = {
    image             = var.image
    command           = var.command
    health_check_path = "/"
    cpu               = 256 # tamaño mínimo de Fargate: abarata la prueba
    memory            = 512
  }
}

output "alb_dns_name" {
  description = "DNS del ALB interno (debe resolver solo a IPs privadas)."
  value       = module.app.alb_dns_name
}

output "service_name" {
  description = "Servicio ECS."
  value       = module.app.service_name
}
