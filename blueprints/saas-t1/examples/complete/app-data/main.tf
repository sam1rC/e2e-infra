locals {
  project = "ct-${var.name_suffix}"

  tags = {
    Project            = local.project
    Environment        = "test"
    Owner              = "platform"
    ManagedBy          = "opentofu"
    Blueprint          = "saas-t1"
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
  alias               = "dr"
  region              = var.dr_region
  allowed_account_ids = [var.account_id]

  default_tags {
    tags = local.tags
  }
}

module "app_data" {
  source = "../../../app-data"

  providers = {
    aws    = aws
    aws.dr = aws.dr
  }

  project     = local.project
  environment = "dev"

  dr_copy         = var.dr_copy
  restore_testing = false

  # Valkey es opcional en SaaS T1: la prueba lo activa para cubrir la capa de E-commerce T1 completa.
  cache = { enabled = var.cache_enabled }
}

output "aurora_cluster_id" {
  description = "Cluster Aurora."
  value       = module.app_data.aurora_cluster_id
}

output "backup_vault_names" {
  description = "Vaults (borrar recovery points antes del destroy)."
  value       = module.app_data.backup_vault_names
}
