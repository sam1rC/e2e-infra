# SaaS T2 = E-commerce T2 + identidad compartida y aislamiento de tenants (plan 9.3). Esta capa reutiliza
# la de ecommerce-t2 tal cual: mismas salidas, mismas rutas SSM (ADR 0004) y mismas decisiones.
module "edge" {
  source = "../../ecommerce-t2/edge"

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
