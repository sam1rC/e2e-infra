locals {
  project = "ct-${var.name_suffix}"

  tags = {
    Project            = local.project
    Environment        = "test"
    Owner              = "platform"
    ManagedBy          = "opentofu"
    Blueprint          = "saas-t2"
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

module "data" {
  source = "../../../data"

  project     = local.project
  environment = "dev"
}

output "instance_id" {
  description = "Instancia PostgreSQL."
  value       = module.data.instance_id
}

output "backup_vault_name" {
  description = "Vault (borrar recovery points antes del destroy)."
  value       = module.data.backup_vault_name
}
