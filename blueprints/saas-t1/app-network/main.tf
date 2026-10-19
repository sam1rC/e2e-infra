# SaaS T1, app plane: reutiliza la capa network de ecommerce-t1 (mismas salidas, rutas SSM y decisiones)
# dentro de la cuenta app-nonprod/app-prod o de la cuenta de un tenant silo.
module "network" {
  source = "../../ecommerce-t1/network"

  project             = var.project
  environment         = var.environment
  cidr_block          = var.cidr_block
  az_names            = var.az_names
  nat_mode            = var.nat_mode
  interface_endpoints = var.interface_endpoints
  dns_firewall_lists  = var.dns_firewall_lists
  alarm_emails        = var.alarm_emails
  tags                = var.tags
}
