# Bootstrap de la cuenta/entorno (runbook docs/runbooks/bootstrap.md): se aplica una vez con credenciales de
# administrador y estado LOCAL; después se renombra backend.tf.migrate a backend.tf y se migra el estado.

module "state_backend" {
  source = "../../../modules/foundation/state-backend"

  project     = var.project
  environment = var.environment

  kms_admin_principal_arns = var.kms_admin_principal_arns
  kms_user_principal_arns  = var.kms_user_principal_arns
}

module "github_oidc" {
  source = "../../../modules/foundation/github-oidc"

  project     = var.project
  environment = var.environment

  github_org         = var.github_org
  github_repo        = var.github_repo
  github_environment = var.github_environment
  create_provider    = var.create_oidc_provider

  state_bucket_arn  = module.state_backend.bucket_arn
  state_kms_key_arn = module.state_backend.kms_key_arn
}

# Artefactos de las Lambdas (T3 y control plane de SaaS T1): el pipeline de la aplicación sube aquí el zip y la
# capa lo referencia por versión. SSE-S3: el código no es un dato del cliente y así CreateFunction no necesita
# permisos sobre una CMK; el bucket sigue siendo privado, versionado y TLS-only (módulo s3-bucket).
module "artifacts" {
  source = "../../../modules/storage/s3-bucket"
  count  = var.artifacts_bucket ? 1 : 0

  project       = var.project
  environment   = var.environment
  purpose       = "data"
  bucket_name   = "${var.project}-${var.environment}-artifacts-${var.account_id}"
  sse_algorithm = "AES256"
}
