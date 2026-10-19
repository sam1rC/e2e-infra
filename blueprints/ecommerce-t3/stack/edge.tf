# Borde: todo lo de CloudFront vive en us-east-1 (certificado del viewer, WAF CLOUDFRONT, logs v2,
# métricas y alarmas de la distribución).
module "edge_kms" {
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

  project        = var.project
  environment    = var.environment
  scope          = "CLOUDFRONT"
  create_web_acl = var.waf_mode == "web_acl"

  # Plan 9.2: en dev las reglas nuevas se prueban en count antes de bloquear (salvo waf_rules_mode).
  managed_rules_mode = coalesce(var.waf_rules_mode, var.environment == "dev" ? "count" : "block")
  log_kms_key_arn    = module.edge_kms.key_arn
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

# Logs de acceso de CloudFront (entrega v2, ADR 0011): SSE-S3, sin ACL.
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

module "site" {
  source    = "../../../modules/edge/cloudfront-static-site"
  providers = { aws = aws.us_east_1 }

  project     = var.project
  environment = var.environment

  domain_names               = [var.domain_name]
  acm_certificate_arn        = local.viewer_certificate_arn
  web_acl_arn                = module.waf.web_acl_arn
  response_headers_policy_id = module.security_headers.policy_id
  spa_error_codes            = var.spa_error_codes
  price_class                = var.price_class
  zone_id                    = var.zone_id
  force_destroy              = !local.prod

  api = {
    domain_name  = module.api.origin_domain_name
    path_pattern = "/api/*"
  }
  api_origin_verify_secret = random_password.origin_verify.result

  log_bucket_arn      = module.cdn_logs.bucket_arn
  access_logs_enabled = true # el bucket se crea en este mismo apply
  log_prefix          = "cloudfront"

  tags = var.tags
}
