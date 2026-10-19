locals {
  guardduty_features = {
    S3_DATA_EVENTS         = var.guardduty_features.s3_data_events
    EBS_MALWARE_PROTECTION = var.guardduty_features.ebs_malware_protection
    RDS_LOGIN_EVENTS       = var.guardduty_features.rds_login_events
    LAMBDA_NETWORK_LOGS    = var.guardduty_features.lambda_network_logs
    EKS_AUDIT_LOGS         = var.guardduty_features.eks_audit_logs
  }

  security_hub_standards = merge(
    var.security_hub_standards.foundational ? {
      foundational = "arn:${local.partition}:securityhub:${local.region}::standards/aws-foundational-security-best-practices/v/${var.security_hub_standards.foundational_ver}"
    } : {},
    var.security_hub_standards.cis ? {
      cis = "arn:${local.partition}:securityhub:${local.region}::standards/cis-aws-foundations-benchmark/v/${var.security_hub_standards.cis_ver}"
    } : {},
  )
}

resource "aws_guardduty_detector" "this" {
  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"

  tags = var.tags
}

resource "aws_guardduty_detector_feature" "this" {
  for_each = local.guardduty_features

  detector_id = aws_guardduty_detector.this.id
  name        = each.key
  status      = each.value ? "ENABLED" : "DISABLED"
}

resource "aws_securityhub_account" "this" {
  enable_default_standards  = false
  auto_enable_controls      = true
  control_finding_generator = "SECURITY_CONTROL"

  # Varios controles de Security Hub evalúan con AWS Config: el recorder debe estar activo antes.
  depends_on = [aws_config_configuration_recorder_status.this]
}

resource "aws_securityhub_standards_subscription" "this" {
  for_each = local.security_hub_standards

  standards_arn = each.value

  depends_on = [aws_securityhub_account.this]
}

resource "aws_accessanalyzer_analyzer" "this" {
  analyzer_name = "${local.name}-analyzer"
  type          = var.access_analyzer_type

  tags = var.tags
}

resource "aws_inspector2_enabler" "this" {
  account_ids    = [local.account_id]
  resource_types = var.inspector_resource_types
}
