locals {
  project = "ct-${var.name_suffix}"

  tags = {
    Project            = local.project
    Environment        = "test"
    Owner              = "platform"
    ManagedBy          = "opentofu"
    Blueprint          = "ecommerce-t1"
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

module "data" {
  source = "../../../data"

  providers = {
    aws    = aws
    aws.dr = aws.dr
  }

  project     = local.project
  environment = "dev"

  # Valores de prueba: sin copia a DR ni restore testing (coste); activa dr_copy para probar la copia.
  dr_copy         = var.dr_copy
  restore_testing = false
}

output "aurora_cluster_id" {
  description = "Cluster Aurora."
  value       = module.data.aurora_cluster_id
}

output "backup_vault_names" {
  description = "Vaults (borrar recovery points antes del destroy)."
  value       = module.data.backup_vault_names
}
