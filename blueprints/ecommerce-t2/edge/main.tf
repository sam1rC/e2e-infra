module "kms" {
  source    = "../../../modules/foundation/kms-key"
  providers = { aws = aws.us_east_1 }

  project                 = var.project
  environment             = var.environment
  purpose                 = "edge"
  deletion_window_in_days = local.prod ? 30 : 7

  service_principals = ["logs.us-east-1.amazonaws.com", "cloudwatch.amazonaws.com", "sns.amazonaws.com"]

  tags = var.tags
}

module "viewer_certificate" {
  source    = "../../../modules/edge/acm-certificate"
  providers = { aws = aws.us_east_1 }
  count     = var.viewer_certificate_arn == null ? 1 : 0

  project             = var.project
  environment         = var.environment
  domain_name         = var.domain_name
  zone_id             = var.zone_id
  wait_for_validation = true

  tags = var.tags
}

module "waf" {
  source    = "../../../modules/edge/waf-web-acl"
  providers = { aws = aws.us_east_1 }

  project     = var.project
  environment = var.environment
  scope       = "CLOUDFRONT"

  managed_rules_mode           = coalesce(var.waf.rules_mode, var.environment == "dev" ? "count" : "block")
  rate_limit_per_5m            = var.waf.rate_limit_per_5m
  count_size_restrictions_body = var.waf.count_size_restrictions_body
  anonymous_ip_list_mode       = var.waf.anonymous_ip_list_mode
  enable_bot_control           = var.waf.bot_control

  log_kms_key_arn    = module.kms.key_arn
  log_retention_days = local.log_retention_days

  tags = var.tags
}

module "security_headers" {
  source    = "../../../modules/edge/security-headers"
  providers = { aws = aws.us_east_1 }

  project     = var.project
  environment = var.environment

  content_security_policy = var.content_security_policy
}

module "cdn_logs" {
  source    = "../../../modules/storage/s3-bucket"
  providers = { aws = aws.us_east_1 }

  project       = var.project
  environment   = var.environment
  purpose       = "logs"
  bucket_name   = "${local.name}-edge-logs-${local.account_id}"
  sse_algorithm = "AES256"
  force_destroy = !local.prod

  lifecycle_config = {
    expiration_days = local.prod ? 365 : 30
  }

  policy_statements = [
    {
      # CloudFront (logging v2) escribe en AWSLogs/<cuenta>/CloudFront/<log_prefix>/...; es la declaración que
      # CloudWatch Logs añadiría por su cuenta (y que OpenTofu borraría en el siguiente apply).
      sid            = "AWSLogDeliveryWrite"
      actions        = ["s3:PutObject"]
      resource_paths = ["/AWSLogs/${local.account_id}/CloudFront/*"]
      principals     = [{ type = "Service", identifiers = ["delivery.logs.amazonaws.com"] }]
      conditions = [
        { test = "StringEquals", variable = "s3:x-amz-acl", values = ["bucket-owner-full-control"] },
        { test = "StringEquals", variable = "aws:SourceAccount", values = [local.account_id] },
        { test = "ArnLike", variable = "aws:SourceArn", values = ["arn:${data.aws_partition.current.partition}:logs:us-east-1:${local.account_id}:delivery-source:${local.name}-cloudfront"] },
      ]
    },
  ]

  tags = var.tags
}

# CloudFront → VPC origin (https-only) → ALB interno. El módulo añade la entrada al SG del ALB desde el SG
# gestionado de CloudFront.
module "cdn" {
  source    = "../../../modules/edge/cloudfront-vpc-origin"
  providers = { aws = aws.us_east_1 }

  project     = var.project
  environment = var.environment

  vpc_id                = local.network["vpc_id"]
  alb_arn               = local.app["alb_arn"]
  alb_dns_name          = local.app["alb_dns_name"]
  alb_security_group_id = local.app["alb_security_group_id"]
  alb_ingress_source    = local.alb_in_us_east_1 ? "cloudfront_managed_sg" : "none"

  domain_names               = [var.domain_name]
  acm_certificate_arn        = local.viewer_certificate_arn
  web_acl_arn                = module.waf.web_acl_arn
  response_headers_policy_id = module.security_headers.policy_id
  static_path_patterns       = var.static_path_patterns
  price_class                = var.price_class
  zone_id                    = var.zone_id

  log_bucket_arn      = module.cdn_logs.bucket_arn
  access_logs_enabled = true # el bucket se crea en este mismo apply
  log_prefix          = "cloudfront"

  tags = var.tags
}

module "alarms" {
  source    = "../../../modules/observability/alarms"
  providers = { aws = aws.us_east_1 }

  project             = var.project
  environment         = var.environment
  name                = "${local.name}-edge"
  kms_key_arn         = module.kms.key_arn
  email_subscriptions = var.alarm_emails

  cloudfront_distributions = { site = { distribution_id = module.cdn.distribution_id } }
  waf_web_acls             = { edge = { web_acl_name = module.waf.web_acl_name } }

  tags = var.tags
}
