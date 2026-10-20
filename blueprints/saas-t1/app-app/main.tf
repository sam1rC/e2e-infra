# SaaS T1, app plane: la capa app de ecommerce-t1 (ALB interno, ECS con ADOT, Aurora, Valkey opcional,
# eventos) más el aislamiento de tenants (rol ABAC + bucket por prefijo + contexto de cifrado por tenant),
# la validación de los JWT de los user pools del control plane y el envío de eventos de uso (metering).
# Aurora en pool (RLS, sql/pool-rls.sql) o bridge (esquema por tenant, sql/bridge-schema-per-tenant.sql);
# en una cuenta silo, isolation_model = "silo" y tenant_id fijo.
module "app" {
  source = "../../ecommerce-t1/app"

  project                     = var.project
  environment                 = var.environment
  domain_name                 = var.domain_name
  zone_id                     = var.zone_id
  alb_certificate_arn         = var.alb_certificate_arn
  service                     = var.service
  allow_internet_egress       = var.allow_internet_egress
  events                      = var.events
  extra_task_role_policies    = merge(var.extra_task_role_policies, local.tenant_policies)
  extra_environment_variables = merge(var.extra_environment_variables, local.tenant_environment)
  tags                        = var.tags
}

# Datos de tenants en S3 (tenants/<tenant>/...), con bucket key (la exige la condición de KMS del rol).
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

# Token vending machine: la aplicación asume este rol con la etiqueta de sesión del tenant del JWT; solo
# alcanza su prefijo y cifra/descifra con el contexto de cifrado de su tenant.
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

  kms_keys = {
    envelope = local.platform_key
  }

  tags = var.tags
}
