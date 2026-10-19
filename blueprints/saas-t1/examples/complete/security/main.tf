# Solo plan: requiere la cuenta de management de una organización de pruebas (crear cuentas es real e
# irreversible a corto plazo; ver modules/organization/org-account).
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

module "security" {
  source = "../../../security"

  project = local.project

  root_id = var.root_id

  accounts = {
    security       = { email = "aws+${local.project}-security@example.com", ou = "security" }
    log-archive    = { email = "aws+${local.project}-logs@example.com", ou = "security" }
    control-plane  = { email = "aws+${local.project}-cp@example.com", ou = "infrastructure" }
    app-nonprod    = { email = "aws+${local.project}-nonprod@example.com", ou = "nonprod", environment = "dev" }
    app-prod       = { email = "aws+${local.project}-prod@example.com", ou = "prod" }
    silo-bigclient = { email = "aws+${local.project}-bigclient@example.com", ou = "silo", tenant_id = "bigclient" }
  }

  guardrails = {
    admin_role_arns = ["arn:aws:iam::*:role/AWSControlTowerExecution", "arn:aws:iam::*:role/OrganizationAccountAccessRole"]
    allowed_regions = ["us-east-1", "us-west-2"]
  }
}

output "account_ids" {
  description = "Cuentas creadas."
  value       = module.security.account_ids
}
