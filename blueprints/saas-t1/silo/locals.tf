locals {
  region = data.aws_region.current.region
  tags   = merge(var.tags, { Tenant = var.tenant_id })

  ssm_parameters = {
    tenant_id       = var.tenant_id
    kms_key_arn     = module.tenant_kms.key_arn
    deploy_role_arn = module.deploy_role.role_arn
  }
}
