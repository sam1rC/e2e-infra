locals {
  name = coalesce(var.name, "${var.project}-${var.environment}-events")

  # ARN de cada regla construido con los nombres (no con los atributos del recurso) para que el trust del
  # rol no cree un ciclo rol -> regla -> destino -> rol.
  rule_arns = {
    for k, _ in var.rules : k => "arn:${data.aws_partition.current.partition}:events:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:rule/${local.name}/${local.name}-${k}"
  }

  rule_patterns = {
    for k, r in var.rules : k => r.event_pattern != null ? r.event_pattern : jsonencode(merge(
      length(r.source_prefixes) > 0 ? { source = [for p in r.source_prefixes : { prefix = p }] } : null,
      length(r.detail_type_prefixes) > 0 ? { "detail-type" = [for p in r.detail_type_prefixes : { prefix = p }] } : null,
    ))
  }

  firehose_arns = distinct([for r in values(var.rules) : r.firehose_arn])

  ssm_prefix = "/${var.project}/${var.environment}/integration"
}
