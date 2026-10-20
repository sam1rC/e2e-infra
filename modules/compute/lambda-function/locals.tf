locals {
  function_name  = "${var.project}-${var.environment}-${var.name}"
  log_group_name = "/aws/lambda/${local.function_name}"
  is_image       = var.image_uri != null
  account_id     = data.aws_caller_identity.current.account_id
}
