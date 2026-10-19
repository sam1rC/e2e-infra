# Capa de organización de SaaS T1 (cuenta de management): OU, cuentas miembro, SCP por OU y delegación de
# los servicios de seguridad en la cuenta security. La línea base de cada cuenta (account-baseline) se
# aplica después desde live/_baseline/<cuenta> con el rol de bootstrap que devuelve esta capa.
resource "aws_organizations_organizational_unit" "security" {
  name      = "Security"
  parent_id = var.root_id

  tags = var.tags
}

resource "aws_organizations_organizational_unit" "infrastructure" {
  name      = "Infrastructure"
  parent_id = var.root_id

  tags = var.tags
}

resource "aws_organizations_organizational_unit" "workloads" {
  name      = "Workloads"
  parent_id = var.root_id

  tags = var.tags
}

resource "aws_organizations_organizational_unit" "nonprod" {
  name      = "NonProd"
  parent_id = aws_organizations_organizational_unit.workloads.id

  tags = var.tags
}

resource "aws_organizations_organizational_unit" "prod" {
  name      = "Prod"
  parent_id = aws_organizations_organizational_unit.workloads.id

  tags = var.tags
}

resource "aws_organizations_organizational_unit" "silo" {
  name      = "Silo"
  parent_id = aws_organizations_organizational_unit.workloads.id

  tags = var.tags
}

module "accounts" {
  source   = "../../../modules/organization/org-account"
  for_each = var.accounts

  project     = var.project
  environment = each.value.environment
  account_key = each.key
  email       = each.value.email
  parent_id   = local.ou_ids[each.value.ou]

  tags = merge(var.tags, each.value.tenant_id == null ? null : { Tenant = each.value.tenant_id })
}

module "guardrails" {
  source   = "../../../modules/organization/org-guardrails"
  for_each = local.guardrail_targets

  project         = var.project
  environment     = each.value.environment
  target_ids      = each.value.ou_ids
  admin_role_arns = var.guardrails.admin_role_arns
  allowed_regions = var.guardrails.allowed_regions

  bootstrap_role_arns = var.guardrails.bootstrap_role_arns
  state_bucket_arns   = var.guardrails.protected_state_buckets
  state_kms_key_arns  = var.guardrails.protected_state_kms_keys

  enable_resource_control_policies = var.guardrails.enable_rcp
  organization_id                  = var.guardrails.organization_id

  tags = var.tags
}

# Administración delegada (A8): la cuenta security agrega hallazgos de toda la organización; la cuenta de
# management no aloja cargas ni consolas de seguridad.
resource "aws_guardduty_organization_admin_account" "this" {
  count = var.delegated_admins ? 1 : 0

  admin_account_id = local.security_account_id
}

resource "aws_securityhub_organization_admin_account" "this" {
  count = var.delegated_admins ? 1 : 0

  admin_account_id = local.security_account_id
}

resource "aws_inspector2_delegated_admin_account" "this" {
  count = var.delegated_admins ? 1 : 0

  account_id = local.security_account_id
}

resource "aws_organizations_delegated_administrator" "this" {
  for_each = local.delegated_service_principals

  account_id        = local.security_account_id
  service_principal = each.value
}
