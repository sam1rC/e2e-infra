locals {
  name = coalesce(var.name, "${var.project}-${var.environment}")

  enable_exec         = coalesce(var.enable_exec, var.environment != "prod")
  enable_fargate_spot = coalesce(var.enable_fargate_spot, var.environment != "prod")

  capacity_providers = concat(["FARGATE"], local.enable_fargate_spot ? ["FARGATE_SPOT"] : [])

  # FARGATE garantiza la base; Spot absorbe el resto según su peso.
  default_strategy = merge(
    { FARGATE = { base = 1, weight = 1 } },
    local.enable_fargate_spot ? { FARGATE_SPOT = { base = 0, weight = var.fargate_spot_weight } } : {},
  )
}
