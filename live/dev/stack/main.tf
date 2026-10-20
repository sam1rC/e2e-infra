module "stack" {
  source = "../../../blueprints/saas-t3/stack"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  project     = var.project
  environment = var.environment

  domain_name                       = var.domain_name
  zone_id                           = var.zone_id
  viewer_certificate_arn            = var.viewer_certificate_arn
  waf_mode                          = var.waf_mode
  waf_rules_mode                    = var.waf_rules_mode
  content_security_policy           = var.content_security_policy
  spa_error_codes                   = var.spa_error_codes
  price_class                       = var.price_class
  usage_plans                       = var.usage_plans
  auth                              = var.auth
  manage_apigw_account_logging_role = var.manage_apigw_account_logging_role
  api_function                      = var.api_function
  origin_verify_version             = var.origin_verify_version
  alarm_emails                      = var.alarm_emails
}
