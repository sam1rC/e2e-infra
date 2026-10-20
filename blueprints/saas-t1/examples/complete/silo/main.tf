# Cimientos de la cuenta de un tenant silo. En la sandbox solo se planifica (necesita un rol de CI de otra
# cuenta y una permissions boundary existentes); en una organización se aplica con el rol de bootstrap.
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

module "silo" {
  source = "../../../silo"

  project     = local.project
  environment = "dev"

  tenant_id = "bigclient"

  deploy_role = {
    trusted_role_arns        = var.deploy_trusted_role_arns
    permissions_boundary_arn = var.permissions_boundary_arn
  }

  budget = {
    monthly_limit_usd            = 10
    alert_emails                 = var.budget_emails
    existing_anomaly_monitor_arn = var.existing_anomaly_monitor_arn
  }
}

output "deploy_role_arn" {
  description = "Rol de despliegue del tenant."
  value       = module.silo.deploy_role_arn
}
