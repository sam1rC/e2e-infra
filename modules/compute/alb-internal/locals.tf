locals {
  name = coalesce(var.name, "${var.project}-${var.environment}")
}
