# SaaS T1, app plane: reutiliza la capa edge de ecommerce-t1 (mismas salidas, rutas SSM y decisiones)
# dentro de la cuenta app-nonprod/app-prod o de la cuenta de un tenant silo.
module "edge" {
  source = "../../ecommerce-t1/edge"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  project                 = var.project
  environment             = var.environment
  domain_name             = var.domain_name
  zone_id                 = var.zone_id
  viewer_certificate_arn  = var.viewer_certificate_arn
  waf                     = var.waf
  content_security_policy = var.content_security_policy
  static_path_patterns    = var.static_path_patterns
  price_class             = var.price_class
  alarm_emails            = var.alarm_emails
  tags                    = var.tags
}
