# SaaS T2: la capa app de ecommerce-t2 (ALB interno + ECS + RDS app_runtime) más el user pool compartido
# de tenants, el bucket de datos con un prefijo por tenant y el rol ABAC que la aplicación asume con la
# etiqueta de sesión del tenant (token vending machine, ADR 0006). Bridge en PostgreSQL: un esquema y un
# rol por tenant con sql/bridge-schema-per-tenant.sql (lo ejecuta el onboarding, no OpenTofu).
module "app" {
  source = "../../ecommerce-t2/app"

  project                  = var.project
  environment              = var.environment
  domain_name              = var.domain_name
  zone_id                  = var.zone_id
  alb_certificate_arn      = var.alb_certificate_arn
  service                  = merge(var.service, { environment_variables = merge(var.service.environment_variables, local.tenant_environment) })
  allow_internet_egress    = var.allow_internet_egress
  extra_task_role_policies = merge(var.extra_task_role_policies, local.tenant_policies)
  tags                     = var.tags
}

module "tenants" {
  source = "../../../modules/identity/cognito-user-pool"

  project     = var.project
  environment = var.environment
  name        = "tenants"
  kms_key_arn = local.platform_key

  tenant_id_attribute = true

  groups = {
    tenant-admins = { description = "Administradores de su tenant", precedence = 10 }
  }

  app_clients = {
    web = {
      callback_urls = local.callback_urls
      logout_urls   = local.logout_urls
    }
  }

  domain             = var.auth.domain_prefix == null ? null : { prefix = var.auth.domain_prefix }
  email              = var.auth.email
  log_retention_days = local.prod ? 365 : 30

  tags = var.tags
}

# Datos de tenants en S3, un prefijo por tenant (tenants/<tenant>/...). Bucket key activada (la exige la
# condición de KMS del rol de tenant).
module "tenant_bucket" {
  source = "../../../modules/storage/s3-bucket"

  project       = var.project
  environment   = var.environment
  purpose       = "data"
  bucket_name   = "${local.name}-tenant-data-${local.account_id}"
  kms_key_arn   = local.platform_key
  force_destroy = !local.prod

  tags = var.tags
}

module "tenant_role" {
  source = "../../../modules/identity/tenant-access-role"

  project           = var.project
  environment       = var.environment
  trusted_role_arns = [module.app.task_role_arn]

  s3_buckets = {
    data = {
      bucket_arn  = module.tenant_bucket.bucket_arn
      prefix      = "tenants/"
      kms_key_arn = local.platform_key
    }
  }

  tags = var.tags
}
