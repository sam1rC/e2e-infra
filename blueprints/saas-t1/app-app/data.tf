data "aws_caller_identity" "current" {}

data "aws_ssm_parameters_by_path" "network" {
  path      = "/${var.project}/${var.environment}/network"
  recursive = true
}
