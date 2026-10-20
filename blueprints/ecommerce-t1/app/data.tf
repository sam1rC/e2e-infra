data "aws_ssm_parameters_by_path" "network" {
  path      = "/${var.project}/${var.environment}/network"
  recursive = true
}

data "aws_ssm_parameters_by_path" "data" {
  path      = "/${var.project}/${var.environment}/data"
  recursive = true
}

data "aws_caller_identity" "current" {}
