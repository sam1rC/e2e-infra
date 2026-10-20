locals {
  name = coalesce(var.name, "${var.project}-${var.account_key}")
}
