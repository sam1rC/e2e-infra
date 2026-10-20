provider "aws" {
  region = "us-east-1"
}

variable "managed_domain_list_ids" {
  description = "IDs de las listas gestionadas de DNS Firewall en esta región (aws route53resolver list-firewall-domain-lists). Los valores por defecto son marcadores: sustitúyelos."
  type        = map(string)
  default = {
    malware = "rslvr-fdl-0123456789abcdef"
  }
  nullable = false
}

module "vpc" {
  source = "../../../../network/vpc"

  project     = "acme"
  environment = "dev"
  cidr_block  = "10.88.0.0/16"
  az_names    = ["us-east-1a", "us-east-1b"]

  nat_mode               = "none"
  enable_flow_logs       = false # solo para el ejemplo
  publish_ssm_parameters = false
}

data "aws_caller_identity" "current" {}

# Los logs de consultas DNS los entrega delivery.logs.amazonaws.com; este ejemplo usa SSE-S3 para no tener
# que autorizar a ese servicio en una CMK.
module "logs_bucket" {
  source = "../../../../storage/s3-bucket"

  project       = "acme"
  environment   = "dev"
  purpose       = "logs"
  sse_algorithm = "AES256"
  force_destroy = true # solo porque es un ejemplo efímero

  policy_statements = [
    {
      sid            = "AWSLogDeliveryWrite"
      actions        = ["s3:PutObject"]
      resource_paths = ["/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]
      principals     = [{ type = "Service", identifiers = ["delivery.logs.amazonaws.com"] }]
      conditions = [
        { test = "StringEquals", variable = "s3:x-amz-acl", values = ["bucket-owner-full-control"] },
        { test = "StringEquals", variable = "aws:SourceAccount", values = [data.aws_caller_identity.current.account_id] },
      ]
    },
    {
      sid            = "AWSLogDeliveryAclCheck"
      actions        = ["s3:GetBucketAcl", "s3:ListBucket"]
      resource_paths = [""]
      principals     = [{ type = "Service", identifiers = ["delivery.logs.amazonaws.com"] }]
      conditions     = [{ test = "StringEquals", variable = "aws:SourceAccount", values = [data.aws_caller_identity.current.account_id] }]
    },
  ]
}

module "dns_firewall" {
  source = "../.."

  project     = "acme"
  environment = "dev"
  vpc_id      = module.vpc.vpc_id

  managed_domain_lists = {
    malware = { domain_list_id = var.managed_domain_list_ids["malware"], priority = 10 }
  }

  query_log_destination_arn = module.logs_bucket.bucket_arn
}

output "rule_group_id" {
  description = "ID del grupo de reglas."
  value       = module.dns_firewall.rule_group_id
}
