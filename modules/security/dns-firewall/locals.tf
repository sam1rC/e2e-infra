locals {
  name = "${var.project}-${var.environment}-dns-firewall"

  mutation_protection = coalesce(var.mutation_protection, var.environment == "prod")
}
