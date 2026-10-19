locals {
  domains = concat([var.domain_name], var.subject_alternative_names)

  create_records = var.zone_id != null
  validate       = local.create_records || var.wait_for_validation
}
