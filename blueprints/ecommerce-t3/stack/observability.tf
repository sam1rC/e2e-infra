module "alarms" {
  source = "../../../modules/observability/alarms"

  project             = var.project
  environment         = var.environment
  kms_key_arn         = module.kms.key_arn
  email_subscriptions = var.alarm_emails

  lambda_functions = local.monitored_lambdas
  http_apis        = { api = { api_id = module.api.api_id } }
  dynamodb_tables  = local.monitored_tables
  aurora_clusters  = local.monitored_aurora

  tags = var.tags
}

# Las métricas de CloudFront y del WAF global solo existen en us-east-1: segunda instancia con su topic.
module "edge_alarms" {
  source    = "../../../modules/observability/alarms"
  providers = { aws = aws.us_east_1 }

  project             = var.project
  environment         = var.environment
  name                = "${local.name}-edge"
  kms_key_arn         = module.edge_kms.key_arn
  email_subscriptions = var.alarm_emails

  cloudfront_distributions = local.monitored_cdn
  waf_web_acls             = local.monitored_waf

  tags = var.tags
}

module "dashboard" {
  source = "../../../modules/observability/dashboard"

  project     = var.project
  environment = var.environment
  name        = "${local.name}-ecommerce-t3"
  alarm_arns  = merge(module.alarms.alarm_arns, module.edge_alarms.alarm_arns)

  lambda_functions         = { for k, v in local.monitored_lambdas : k => { function_name = v.function_name } }
  http_apis                = { api = { api_id = module.api.api_id } }
  dynamodb_tables          = local.monitored_tables
  aurora_clusters          = { for k, v in local.monitored_aurora : k => { cluster_id = v.cluster_id } }
  cloudfront_distributions = local.monitored_cdn
  waf_web_acls             = local.monitored_waf
}
