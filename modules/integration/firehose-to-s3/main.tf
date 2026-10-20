resource "aws_cloudwatch_log_group" "this" {
  name              = local.log_group_name
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

resource "aws_cloudwatch_log_stream" "s3_delivery" {
  name           = local.log_stream_name
  log_group_name = aws_cloudwatch_log_group.this.name
}

resource "aws_kinesis_firehose_delivery_stream" "this" {
  name        = local.stream_name
  destination = "extended_s3"

  # Cifrado en reposo del búfer del stream con la CMK (solo disponible en streams DirectPut, que es el caso).
  server_side_encryption {
    enabled  = true
    key_type = "CUSTOMER_MANAGED_CMK"
    key_arn  = var.kms_key_arn
  }

  extended_s3_configuration {
    role_arn            = aws_iam_role.this.arn
    bucket_arn          = var.bucket_arn
    kms_key_arn         = var.kms_key_arn
    prefix              = local.prefix
    error_output_prefix = local.error_prefix
    compression_format  = var.compression_format
    buffering_interval  = var.buffer.interval_seconds
    buffering_size      = var.buffer.size_mb
    s3_backup_mode      = "Disabled"

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.this.name
      log_stream_name = aws_cloudwatch_log_stream.s3_delivery.name
    }

    dynamic "dynamic_partitioning_configuration" {
      for_each = local.partitioned ? [1] : []

      content {
        enabled        = true
        retry_duration = 300
      }
    }

    processing_configuration {
      enabled = true

      dynamic "processors" {
        for_each = local.partitioned ? [var.dynamic_partitioning] : []

        content {
          type = "MetadataExtraction"

          parameters {
            parameter_name  = "JsonParsingEngine"
            parameter_value = "JQ-1.6"
          }

          parameters {
            parameter_name  = "MetadataExtractionQuery"
            parameter_value = "{${processors.value.key_name}: ${processors.value.jq_query}}"
          }
        }
      }

      # Un evento por línea: los objetos se pueden consultar con Athena sin postprocesado. El salto de línea es
      # el delimitador por defecto; AWS no devuelve el parámetro Delimiter y declararlo dejaba un cambio
      # perpetuo en el plan (sandbox, 2026-10-14).
      processors {
        type = "AppendDelimiterToRecord"
      }
    }
  }

  tags = merge(var.tags, { Name = local.stream_name })

  depends_on = [aws_iam_role_policy.this]
}
