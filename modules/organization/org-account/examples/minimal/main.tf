provider "aws" {
  region = "us-east-1"
}

module "account" {
  source = "../.."

  project     = "acme"
  environment = "prod"
  account_key = "log-archive"
  email       = "aws+acme-log-archive@example.com"
  parent_id   = "ou-abcd-12345678"
}

output "account_id" {
  description = "ID de la cuenta."
  value       = module.account.account_id
}
