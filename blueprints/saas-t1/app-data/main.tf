# SaaS T1, app plane: reutiliza la capa data de ecommerce-t1 (mismas salidas, rutas SSM y decisiones)
# dentro de la cuenta app-nonprod/app-prod o de la cuenta de un tenant silo.
module "data" {
  source = "../../ecommerce-t1/data"

  providers = {
    aws    = aws
    aws.dr = aws.dr
  }

  project         = var.project
  environment     = var.environment
  aurora          = var.aurora
  cache           = var.cache
  dr_copy         = var.dr_copy
  restore_testing = var.restore_testing
  tags            = var.tags
}
