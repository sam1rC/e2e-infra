# SaaS T2 = E-commerce T2 + identidad compartida y aislamiento de tenants (plan 9.3). Esta capa reutiliza
# la de ecommerce-t2 tal cual: mismas salidas, mismas rutas SSM (ADR 0004) y mismas decisiones.
module "data" {
  source = "../../ecommerce-t2/data"

  project        = var.project
  environment    = var.environment
  engine_version = var.engine_version
  instance_class = var.instance_class
  multi_az       = var.multi_az
  storage        = var.storage
  tags           = var.tags
}
