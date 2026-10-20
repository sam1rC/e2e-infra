provider "aws" {
  region = "us-east-1"
}

module "vpc" {
  source = "../../../vpc"

  project     = "acme"
  environment = "dev"
  cidr_block  = "10.20.0.0/16"
  az_names    = ["us-east-1a", "us-east-1b"]

  nat_mode         = "none"
  enable_flow_logs = false # solo para el ejemplo
}

resource "aws_security_group" "app" {
  name        = "acme-dev-app-example"
  description = "Security group de aplicacion del ejemplo"
  vpc_id      = module.vpc.vpc_id
}

module "vpc_endpoints" {
  source = "../.."

  project         = "acme"
  environment     = "dev"
  vpc_id          = module.vpc.vpc_id
  vpc_cidr_block  = module.vpc.vpc_cidr_block
  subnet_ids      = module.vpc.subnet_ids["app"]
  route_table_ids = concat(module.vpc.route_table_ids["app"], module.vpc.route_table_ids["data"])

  allowed_security_group_ids = {
    app = aws_security_group.app.id
  }
}

output "interface_endpoint_ids" {
  description = "Endpoints de interfaz creados."
  value       = module.vpc_endpoints.interface_endpoint_ids
}
