resource "aws_s3_account_public_access_block" "this" {
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_ebs_encryption_by_default" "this" {
  enabled = true
}

resource "aws_ebs_default_kms_key" "this" {
  key_arn = module.kms.key_arn

  depends_on = [aws_ebs_encryption_by_default.this]
}

resource "aws_iam_account_password_policy" "this" {
  minimum_password_length        = var.password_policy.minimum_length
  require_lowercase_characters   = true
  require_uppercase_characters   = true
  require_numbers                = true
  require_symbols                = true
  allow_users_to_change_password = true
  max_password_age               = var.password_policy.max_age_days
  password_reuse_prevention      = var.password_policy.reuse_prevented
}

module "budgets" {
  source = "../budgets"
  count  = var.budget == null ? 0 : 1

  project     = var.project
  environment = var.environment

  monthly_limit_usd     = var.budget.monthly_limit_usd
  alert_emails          = var.budget.alert_emails
  anomaly_threshold_usd = var.budget.anomaly_threshold_usd

  tags = var.tags
}
