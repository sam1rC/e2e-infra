# Web ACL de CloudFront: debe crearse en us-east-1.
provider "aws" {
  region = "us-east-1"
}

module "waf" {
  source = "../.."

  project     = "acme"
  environment = "dev"
  scope       = "CLOUDFRONT"
}

output "web_acl_arn" {
  description = "ARN del Web ACL."
  value       = module.waf.web_acl_arn
}
