provider "aws" {
  region = "us-east-1"
}

module "budgets" {
  source = "../.."

  project           = "acme"
  environment       = "dev"
  monthly_limit_usd = 200
  alert_emails      = ["team@example.com"]
}

output "budget_name" {
  description = "Nombre del presupuesto."
  value       = module.budgets.budget_name
}
