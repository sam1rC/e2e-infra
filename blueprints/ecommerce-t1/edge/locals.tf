locals {
  name       = "${var.project}-${var.environment}"
  prod       = var.environment == "prod"
  account_id = data.aws_caller_identity.current.account_id

  network = {
    for i, n in data.aws_ssm_parameters_by_path.network.names :
    trimprefix(n, "/${var.project}/${var.environment}/network/") => nonsensitive(data.aws_ssm_parameters_by_path.network.values[i])
  }
  app = {
    for i, n in data.aws_ssm_parameters_by_path.app.names :
    trimprefix(n, "/${var.project}/${var.environment}/app/") => nonsensitive(data.aws_ssm_parameters_by_path.app.values[i])
  }

  log_retention_days     = local.prod ? 365 : 30
  viewer_certificate_arn = var.viewer_certificate_arn != null ? var.viewer_certificate_arn : module.viewer_certificate[0].certificate_arn
}
