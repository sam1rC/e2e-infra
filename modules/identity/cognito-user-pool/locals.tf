locals {
  # Conocido al planificar aunque la Lambda se cree en el mismo apply.
  pre_token = var.pre_token_generation_enabled != null ? var.pre_token_generation_enabled : var.pre_token_generation_lambda_arn != null

  name = "${var.project}-${var.environment}-${var.name}"

  mfa_configuration   = coalesce(var.mfa_configuration, var.environment == "prod" ? "ON" : "OPTIONAL")
  deletion_protection = coalesce(var.deletion_protection, var.environment != "dev")

  plus            = var.feature_plan == "PLUS"
  threat_mode     = coalesce(var.threat_protection.mode, var.environment == "prod" ? "ENFORCED" : "AUDIT")
  notify_on_risk  = var.threat_protection.notify != null
  log_group_root  = "/aws/vendedlogs/cognito/${local.name}"
  managed_login   = var.domain != null
  custom_domain   = try(var.domain.custom_domain, null) != null
  ssm_prefix      = "/${var.project}/${var.environment}/identity/${var.name}"
  tenant_id_claim = var.tenant_id_attribute ? "custom:tenant_id" : null
}
