provider "aws" {
  region = "us-east-1"
}

variable "name_suffix" {
  description = "Sufijo para nombres de la prueba (evita colisiones en ejecuciones paralelas)."
  type        = string
  default     = "example"
  nullable    = false
}

module "vpc" {
  source = "../../../vpc"

  project     = "acme-${var.name_suffix}"
  environment = "dev"
  cidr_block  = "10.40.0.0/16"
  az_names    = ["us-east-1a", "us-east-1b"]

  nat_mode               = "none"
  enable_flow_logs       = false # solo para el ejemplo
  publish_ssm_parameters = false
}

resource "aws_security_group" "app" {
  name        = "acme-${var.name_suffix}-app"
  description = "Security group de aplicacion del ejemplo"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_security_group" "worker" {
  name        = "acme-${var.name_suffix}-worker"
  description = "Security group de workers del ejemplo"
  vpc_id      = module.vpc.vpc_id
}

module "vpc_endpoints" {
  source = "../.."

  project         = "acme-${var.name_suffix}"
  environment     = "dev"
  vpc_id          = module.vpc.vpc_id
  vpc_cidr_block  = module.vpc.vpc_cidr_block
  subnet_ids      = module.vpc.subnet_ids["app"]
  route_table_ids = concat(module.vpc.route_table_ids["app"], module.vpc.route_table_ids["data"])

  interface_services = ["ecr.api", "ecr.dkr", "logs", "secretsmanager", "sts", "kms", "xray", "monitoring", "ssm", "ssmmessages"]
  gateway_services   = ["s3", "dynamodb"]

  allowed_security_group_ids = {
    app    = aws_security_group.app.id
    worker = aws_security_group.worker.id
  }

  s3_additional_bucket_arns = ["arn:aws:s3:::amazonlinux-2-repos-us-east-1"]

  tags = {
    Owner = "platform"
  }
}

output "interface_endpoint_ids" {
  description = "Endpoints de interfaz creados."
  value       = module.vpc_endpoints.interface_endpoint_ids
}

output "gateway_endpoint_ids" {
  description = "Endpoints gateway creados."
  value       = module.vpc_endpoints.gateway_endpoint_ids
}
