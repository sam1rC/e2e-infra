provider "aws" {
  region = "us-east-1"
}

variable "image" {
  description = "Imagen por digest (repo@sha256:...)."
  type        = string
  default     = "123456789012.dkr.ecr.us-east-1.amazonaws.com/acme-dev-worker@sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
  nullable    = false
}

module "vpc" {
  source = "../../../../network/vpc"

  project     = "acme"
  environment = "dev"
  cidr_block  = "10.70.0.0/16"
  az_names    = ["us-east-1a", "us-east-1b"]

  nat_mode         = "none"
  enable_flow_logs = false # solo para el ejemplo
}

module "kms" {
  source = "../../../../foundation/kms-key"

  project     = "acme"
  environment = "dev"
  purpose     = "ecs"

  service_principals = ["logs.us-east-1.amazonaws.com"]
}

module "cluster" {
  source = "../../../ecs-cluster"

  project     = "acme"
  environment = "dev"
  kms_key_arn = module.kms.key_arn
}

# Un worker sin balanceador: sin entrada y sin salida hasta que se declaren egress_rules.
module "service" {
  source = "../.."

  project         = "acme"
  environment     = "dev"
  name            = "worker"
  cluster_arn     = module.cluster.cluster_arn
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.subnet_ids["app"]
  image           = var.image
  log_kms_key_arn = module.kms.key_arn
}

output "service_name" {
  description = "Nombre del servicio."
  value       = module.service.service_name
}
