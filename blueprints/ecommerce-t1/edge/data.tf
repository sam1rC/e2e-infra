# Región de la aplicación: decide quién crea la regla de entrada del ALB (alb_access.tf).
data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_ssm_parameters_by_path" "network" {
  path      = "/${var.project}/${var.environment}/network"
  recursive = true
}

data "aws_ssm_parameters_by_path" "app" {
  path      = "/${var.project}/${var.environment}/app"
  recursive = true
}

data "aws_partition" "current" {}
