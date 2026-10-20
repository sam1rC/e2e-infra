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

module "network" {
  source = "../../../network"

  project     = local.project
  environment = "dev"

  az_names     = ["${var.region}a", "${var.region}b"]
  alarm_emails = var.alarm_emails
}

output "vpc_id" {
  description = "ID de la VPC."
  value       = module.network.vpc_id
}

output "nat_gateway_ids" {
  description = "NAT creadas (borrarlas es lo más urgente si el destroy falla)."
  value       = module.network.nat_gateway_ids
}
