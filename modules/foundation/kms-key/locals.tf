locals {
  name        = "${var.project}-${var.environment}-${var.purpose}"
  alias_name  = "alias/${local.name}"
  account_id  = data.aws_caller_identity.current.account_id
  root_arn    = "arn:${data.aws_partition.current.partition}:iam::${local.account_id}:root"
  description = coalesce(var.description, "CMK ${var.purpose} de ${var.project}/${var.environment}")
}
