provider "aws" {
  region = "us-east-1"
}

# En la cuenta silo de un tenant: el rol de apply del CI del control plane despliega aquí.
module "deploy_role" {
  source = "../.."

  project           = "acme"
  environment       = "prod"
  name              = "silo-deploy"
  trusted_role_arns = ["arn:aws:iam::111111111111:role/gha-apply-prod"]

  managed_policy_arns = {
    admin = "arn:aws:iam::aws:policy/AdministratorAccess"
  }
  permissions_boundary_arn = "arn:aws:iam::222222222222:policy/acme-deploy-boundary"
}

output "role_arn" {
  description = "ARN del rol de despliegue."
  value       = module.deploy_role.role_arn
}
