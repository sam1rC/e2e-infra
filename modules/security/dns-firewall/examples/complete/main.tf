provider "aws" {
  region = "us-east-1"
}

variable "name_suffix" {
  description = "Sufijo para nombres de la prueba (evita colisiones en ejecuciones paralelas)."
  type        = string
  default     = "example"
  nullable    = false
}

variable "managed_domain_list_ids" {
  description = "IDs de las listas gestionadas de DNS Firewall en us-east-1 (aws route53resolver list-firewall-domain-lists, comprobados el 2026-10-05). En otra región son distintos: sustitúyelos."
  type        = map(string)
  default = {
    malware   = "rslvr-fdl-2c46f2ecbfec4dcc" # AWSManagedDomainsMalwareDomainList
    botnet    = "rslvr-fdl-aa970e9eb1ca4777" # AWSManagedDomainsBotnetCommandandControl
    threats   = "rslvr-fdl-15f4860b1ad54ead" # AWSManagedDomainsAggregateThreatList
    guardduty = "rslvr-fdl-984dae9d8bac4e2b" # AWSManagedDomainsAmazonGuardDutyThreatList
  }
  nullable = false
}

module "vpc" {
  source = "../../../../network/vpc"

  project     = "acme-${var.name_suffix}"
  environment = "dev"
  cidr_block  = "10.89.0.0/16"
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

  project       = "acme-${var.name_suffix}"
  environment   = "dev"
  purpose       = "logs"
  sse_algorithm = "AES256"
  force_destroy = true # solo porque es un ejemplo efímero

  policy_statements = [
    {
      sid     = "AWSLogDeliveryWrite"
      actions = ["s3:PutObject"]
      # Resolver escribe bajo el prefijo del destino (query_log_destination_arn = <bucket>/dns), no en la raíz:
      # sin el prefijo la asociación queda en FAILED con LogDestinationPermissionIssueException (visto en AWS).
      resource_paths = ["/dns/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]
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

# AWSManagedDomainsMalwareDomainList, AWSManagedDomainsBotnetCommandandControl y
# AWSManagedDomainsAggregateThreatList, en ese orden de prioridad.
module "dns_firewall" {
  source = "../.."

  project     = "acme-${var.name_suffix}"
  environment = "dev"
  vpc_id      = module.vpc.vpc_id

  managed_domain_lists = {
    malware   = { domain_list_id = var.managed_domain_list_ids["malware"], priority = 10 }
    botnet    = { domain_list_id = var.managed_domain_list_ids["botnet"], priority = 20, block_response = "NODATA" }
    threats   = { domain_list_id = var.managed_domain_list_ids["threats"], priority = 30, action = "ALERT" }
    guardduty = { domain_list_id = var.managed_domain_list_ids["guardduty"], priority = 40 }
  }

  query_log_destination_arn = "${module.logs_bucket.bucket_arn}/dns"
  association_priority      = 200
  fail_open                 = false
  mutation_protection       = false # solo porque es un ejemplo efímero
}

output "rule_group_id" {
  description = "ID del grupo de reglas."
  value       = module.dns_firewall.rule_group_id
}
