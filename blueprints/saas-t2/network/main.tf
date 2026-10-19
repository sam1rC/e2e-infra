# SaaS T2 = E-commerce T2 + identidad compartida y aislamiento de tenants (plan 9.3). Esta capa reutiliza
# la de ecommerce-t2 tal cual: mismas salidas, mismas rutas SSM (ADR 0004) y mismas decisiones.
module "network" {
  source = "../../ecommerce-t2/network"

  project             = var.project
  environment         = var.environment
  cidr_block          = var.cidr_block
  az_names            = var.az_names
  interface_endpoints = var.interface_endpoints
  alarm_emails        = var.alarm_emails
  tags                = var.tags
}
