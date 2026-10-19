resource "aws_cloudwatch_log_group" "this" {
  name              = local.log_group_name
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

# --- Dead-letter opcional: cola cifrada con la CMK ---------------------------------------------------------------
resource "aws_sqs_queue" "dlq" {
  count = var.enable_dlq ? 1 : 0

  name                      = "${local.function_name}-dlq"
  message_retention_seconds = var.dlq_retention_days * 86400
  kms_master_key_id         = var.kms_key_arn

  tags = merge(var.tags, { Name = "${local.function_name}-dlq" })
}

# --- Firma de código opcional --------------------------------------------------------------------------------------
resource "aws_lambda_code_signing_config" "this" {
  count = var.code_signing == null ? 0 : 1

  description = "Perfiles de firma permitidos para ${local.function_name}"

  allowed_publishers {
    signing_profile_version_arns = var.code_signing.signing_profile_version_arns
  }

  policies {
    untrusted_artifact_on_deployment = var.code_signing.policy
  }
}

# --- Seguridad de red: sin entrada, salida solo a lo declarado ---------------------------------------------------
resource "aws_security_group" "this" {
  count = var.vpc_config == null ? 0 : 1

  name_prefix = "${local.function_name}-"
  description = "Lambda ${local.function_name}: sin entrada, salida solo a destinos declarados"
  vpc_id      = var.vpc_config.vpc_id

  # Sin reglas en línea; Terraform retira la salida abierta que AWS crea por defecto.

  tags = merge(var.tags, { Name = local.function_name })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_egress_rule" "this" {
  for_each = var.vpc_config == null ? {} : var.vpc_config.egress_rules

  security_group_id            = aws_security_group.this[0].id
  referenced_security_group_id = each.value.security_group_id
  prefix_list_id               = each.value.prefix_list_id
  cidr_ipv4                    = each.value.cidr_ipv4
  ip_protocol                  = each.value.protocol
  from_port                    = each.value.port
  to_port                      = each.value.port
  description                  = each.value.description

  tags = merge(var.tags, { Name = "${local.function_name}-to-${each.key}" })
}

resource "aws_lambda_function" "this" {
  function_name = local.function_name
  description   = "${var.project} ${var.environment} ${var.name}"
  role          = aws_iam_role.this.arn

  package_type      = local.is_image ? "Image" : "Zip"
  image_uri         = var.image_uri
  s3_bucket         = var.s3_bucket
  s3_key            = var.s3_key
  s3_object_version = var.s3_object_version
  runtime           = var.runtime
  handler           = var.handler

  architectures                  = [var.architecture]
  memory_size                    = var.memory_size
  timeout                        = var.timeout_seconds
  reserved_concurrent_executions = coalesce(var.reserved_concurrent_executions, -1)
  kms_key_arn                    = var.kms_key_arn
  code_signing_config_arn        = one(aws_lambda_code_signing_config.this[*].arn)

  # Tracing nativo de Lambda; la instrumentación de código usa OpenTelemetry (capa ADOT), no el SDK de X-Ray.
  tracing_config {
    mode = "Active"
  }

  logging_config {
    log_format            = "JSON"
    log_group             = aws_cloudwatch_log_group.this.name
    application_log_level = var.application_log_level
    system_log_level      = var.system_log_level
  }

  dynamic "environment" {
    for_each = length(var.environment_variables) > 0 ? [var.environment_variables] : []

    content {
      variables = environment.value
    }
  }

  dynamic "vpc_config" {
    for_each = var.vpc_config == null ? [] : [var.vpc_config]

    content {
      subnet_ids                  = vpc_config.value.subnet_ids
      security_group_ids          = [aws_security_group.this[0].id]
      ipv6_allowed_for_dual_stack = false
    }
  }

  dynamic "dead_letter_config" {
    for_each = aws_sqs_queue.dlq[*].arn

    content {
      target_arn = dead_letter_config.value
    }
  }

  tags = merge(var.tags, { Name = local.function_name })

  depends_on = [
    aws_cloudwatch_log_group.this,
    aws_iam_role_policy.base,
  ]
}
