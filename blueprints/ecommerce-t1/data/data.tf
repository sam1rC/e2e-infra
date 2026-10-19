data "aws_region" "current" {}

data "aws_region" "dr" {
  provider = aws.dr
}

# Salidas de la capa network (ADR 0004): una sola lectura por capa productora.
data "aws_ssm_parameters_by_path" "network" {
  path      = "/${var.project}/${var.environment}/network"
  recursive = true
}
