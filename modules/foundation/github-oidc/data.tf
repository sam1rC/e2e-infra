data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_iam_openid_connect_provider" "existing" {
  count = var.create_provider ? 0 : 1

  url = "https://${local.oidc_host}"
}
