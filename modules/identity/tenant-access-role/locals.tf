locals {
  role_name = "${var.project}-${var.environment}-${var.name}"

  # Variable de política IAM con el tenant de la sesión: "${aws:PrincipalTag/<clave>}" (literal, la resuelve IAM).
  tenant_ref = "$${aws:PrincipalTag/${var.tenant_tag_key}}"

  dynamodb_write_actions = [
    "dynamodb:BatchGetItem",
    "dynamodb:BatchWriteItem",
    "dynamodb:ConditionCheckItem",
    "dynamodb:DeleteItem",
    "dynamodb:GetItem",
    "dynamodb:PutItem",
    "dynamodb:Query",
    "dynamodb:UpdateItem",
  ]
  dynamodb_read_actions = [
    "dynamodb:BatchGetItem",
    "dynamodb:ConditionCheckItem",
    "dynamodb:GetItem",
    "dynamodb:Query",
  ]

  # Recursos de cada tabla: la tabla y, si se pide, sus índices.
  dynamodb_resources = {
    for k, t in var.dynamodb_tables :
    k => t.include_indexes ? [t.table_arn, "${t.table_arn}/index/*"] : [t.table_arn]
  }

  # Sid alfanumérico estable a partir de la clave del mapa (p. ej. "order-items" -> "OrderItems").
  sid_suffix = {
    for k in distinct(concat(keys(var.dynamodb_tables), keys(var.s3_buckets))) :
    k => join("", [for w in split("-", replace(k, "_", "-")) : title(w)])
  }

  s3_region_service = "s3.${data.aws_region.current.region}.amazonaws.com"
}
