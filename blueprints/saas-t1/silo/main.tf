# Cimientos de la cuenta de un tenant silo (SaaS T1). Se aplica una vez por tenant, con el rol de bootstrap
# de la cuenta (salida de la capa security), después de account-baseline. Las capas app-network, app-data,
# app-app y app-edge se despliegan luego en esta cuenta con un directorio de live/ por tenant (blast radius
# mínimo): mismo código que el app plane compartido, otros valores.

# CMK dedicada del tenant: sus datos no comparten clave con ningún otro tenant.
module "tenant_kms" {
  source = "../../../modules/foundation/kms-key"

  project                 = var.project
  environment             = var.environment
  purpose                 = "tenant-${var.tenant_id}"
  deletion_window_in_days = 30

  service_principals = ["logs.${local.region}.amazonaws.com"]
  via_services = [
    "rds.${local.region}.amazonaws.com",
    "secretsmanager.${local.region}.amazonaws.com",
    "s3.${local.region}.amazonaws.com",
    "dynamodb.${local.region}.amazonaws.com",
  ]

  tags = local.tags
}

# Rol de despliegue: lo asume el pipeline del control plane (onboarding de un tenant silo → workflow_dispatch).
module "deploy_role" {
  source = "../../../modules/organization/cross-account-role"

  project           = var.project
  environment       = var.environment
  name              = "silo-deploy"
  trusted_role_arns = var.deploy_role.trusted_role_arns
  organization_id   = var.deploy_role.organization_id

  managed_policy_arns      = var.deploy_role.managed_policy_arns
  permissions_boundary_arn = var.deploy_role.permissions_boundary_arn

  tags = local.tags
}

module "budget" {
  source = "../../../modules/foundation/budgets"

  project                      = var.project
  environment                  = var.environment
  monthly_limit_usd            = var.budget.monthly_limit_usd
  alert_emails                 = var.budget.alert_emails
  existing_anomaly_monitor_arn = var.budget.existing_anomaly_monitor_arn

  tags = local.tags
}

resource "aws_ssm_parameter" "layer" {
  for_each = local.ssm_parameters

  name  = "/${var.project}/${var.environment}/tenant/${each.key}"
  type  = "String"
  value = each.value

  tags = local.tags
}
