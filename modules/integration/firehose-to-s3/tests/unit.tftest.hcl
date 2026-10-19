mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }

  mock_data "aws_region" {
    defaults = {
      region = "us-east-1"
    }
  }

  # Un JSON válido: aws_iam_role rechaza el texto aleatorio que genera el mock.
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/acme-dev-events"
    }
  }

  mock_resource "aws_cloudwatch_log_group" {
    defaults = {
      arn = "arn:aws:logs:us-east-1:123456789012:log-group:/aws/kinesisfirehose/acme-dev-events"
    }
  }

  mock_resource "aws_kinesis_firehose_delivery_stream" {
    defaults = {
      arn = "arn:aws:firehose:us-east-1:123456789012:deliverystream/acme-dev-events"
    }
  }
}

variables {
  project     = "acme"
  environment = "dev"
  bucket_arn  = "arn:aws:s3:::acme-dev-data-123456789012"
  kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/11111111-2222-3333-4444-555555555555"
}

run "stream_delivers_to_s3_with_cmk_gzip_and_date_partitions" {
  command = plan

  assert {
    condition = (
      aws_kinesis_firehose_delivery_stream.this.name == "acme-dev-events" &&
      aws_kinesis_firehose_delivery_stream.this.destination == "extended_s3"
    )
    error_message = "El stream debe llamarse <project>-<env>-<name> y entregar a S3 extendido."
  }

  assert {
    condition = length(aws_kinesis_firehose_delivery_stream.this.extended_s3_configuration) == 1 && alltrue([
      for c in aws_kinesis_firehose_delivery_stream.this.extended_s3_configuration :
      c.bucket_arn == var.bucket_arn &&
      c.kms_key_arn == var.kms_key_arn &&
      c.compression_format == "GZIP" &&
      c.prefix == "events/!{timestamp:yyyy/MM/dd}/" &&
      c.error_output_prefix == "errors/!{firehose:error-output-type}/!{timestamp:yyyy/MM/dd}/" &&
      c.s3_backup_mode == "Disabled"
    ])
    error_message = "Debe entregar al bucket con la CMK, GZIP, partición por fecha y un prefijo de errores por tipo de error."
  }

  assert {
    condition     = alltrue([for c in aws_kinesis_firehose_delivery_stream.this.extended_s3_configuration : c.buffering_interval == 60 && c.buffering_size == 5])
    error_message = "El búfer por defecto es 60 s y 5 MB."
  }
}

run "stream_is_encrypted_with_the_cmk_at_rest" {
  command = plan

  assert {
    condition = (
      length(aws_kinesis_firehose_delivery_stream.this.server_side_encryption) == 1 &&
      alltrue([
        for s in aws_kinesis_firehose_delivery_stream.this.server_side_encryption :
        s.enabled == true && s.key_type == "CUSTOMER_MANAGED_CMK" && s.key_arn == var.kms_key_arn
      ])
    )
    error_message = "El búfer del stream debe cifrarse con la CMK del entorno."
  }
}

run "delivery_errors_go_to_an_encrypted_log_group" {
  command = plan

  variables {
    log_retention_days = 30
  }

  assert {
    condition = (
      aws_cloudwatch_log_group.this.name == "/aws/kinesisfirehose/acme-dev-events" &&
      aws_cloudwatch_log_group.this.kms_key_id == var.kms_key_arn &&
      aws_cloudwatch_log_group.this.retention_in_days == 30 &&
      aws_cloudwatch_log_stream.s3_delivery.name == "S3Delivery"
    )
    error_message = "Los errores de entrega deben ir a un log group cifrado, con retención y un stream predefinido."
  }

  assert {
    condition = alltrue([
      for c in aws_kinesis_firehose_delivery_stream.this.extended_s3_configuration :
      alltrue([for l in c.cloudwatch_logging_options : l.enabled == true && l.log_stream_name == "S3Delivery"])
    ])
    error_message = "El stream debe tener activado el registro de errores en CloudWatch."
  }
}

run "without_dynamic_partitioning_only_appends_newline" {
  command = plan

  assert {
    condition = length(aws_kinesis_firehose_delivery_stream.this.extended_s3_configuration) == 1 && alltrue([
      for c in aws_kinesis_firehose_delivery_stream.this.extended_s3_configuration :
      length(c.dynamic_partitioning_configuration) == 0 &&
      alltrue([for p in c.processing_configuration : p.enabled == true && length(p.processors) == 1 && alltrue([for pr in p.processors : pr.type == "AppendDelimiterToRecord"])])
    ])
    error_message = "Sin partición dinámica solo debe haber el procesador que separa los eventos por línea."
  }
}

run "dynamic_partitioning_extracts_tenant_into_the_prefix" {
  command = plan

  variables {
    buffer = { size_mb = 64 }
    prefix = "usage/"
    dynamic_partitioning = {
      key_name = "tenant_id"
      jq_query = ".detail.tenant_id"
    }
  }

  assert {
    condition = length(aws_kinesis_firehose_delivery_stream.this.extended_s3_configuration) == 1 && alltrue([
      for c in aws_kinesis_firehose_delivery_stream.this.extended_s3_configuration :
      c.prefix == "usage/!{partitionKeyFromQuery:tenant_id}/!{timestamp:yyyy/MM/dd}/" &&
      alltrue([for d in c.dynamic_partitioning_configuration : d.enabled == true])
    ])
    error_message = "El prefijo debe incluir la clave del tenant extraída del evento."
  }

  assert {
    condition = alltrue([
      for c in aws_kinesis_firehose_delivery_stream.this.extended_s3_configuration :
      alltrue([
        for p in c.processing_configuration :
        toset([for pr in p.processors : pr.type]) == toset(["MetadataExtraction", "AppendDelimiterToRecord"])
      ])
    ])
    error_message = "Debe haber un procesador de extracción de metadatos y otro de delimitador."
  }

  assert {
    condition = anytrue(flatten([
      for c in aws_kinesis_firehose_delivery_stream.this.extended_s3_configuration : [
        for p in c.processing_configuration : [
          for pr in p.processors : anytrue([
            for pa in pr.parameters : pa.parameter_name == "MetadataExtractionQuery" && pa.parameter_value == "{tenant_id: .detail.tenant_id}"
          ]) if pr.type == "MetadataExtraction"
        ]
      ]
    ]))
    error_message = "La consulta JQ debe extraer tenant_id de .detail.tenant_id."
  }
}

run "trust_is_limited_to_this_stream_and_account" {
  command = plan

  assert {
    condition = length(data.aws_iam_policy_document.assume.statement) == 1 && alltrue([
      for s in data.aws_iam_policy_document.assume.statement :
      toset([for c in s.condition : "${c.variable}=${join(",", c.values)}"]) == toset([
        "aws:SourceAccount=123456789012",
        "aws:SourceArn=arn:aws:firehose:us-east-1:123456789012:deliverystream/acme-dev-events",
      ])
    ])
    error_message = "El trust del rol debe limitarse a firehose.amazonaws.com, esta cuenta y este stream."
  }
}

run "role_policy_is_scoped_to_bucket_key_and_log_stream" {
  command = plan

  assert {
    condition = (
      toset([for s in data.aws_iam_policy_document.this.statement : s.sid]) == toset(["WriteObjectsToBucket", "UseKeyThroughS3AndFirehose", "WriteDeliveryErrorLogs"]) &&
      alltrue([for s in data.aws_iam_policy_document.this.statement : s.effect == "Allow"])
    )
    error_message = "La política debe tener solo las tres sentencias previstas."
  }

  assert {
    condition = anytrue([
      for s in data.aws_iam_policy_document.this.statement :
      s.sid == "WriteObjectsToBucket" && toset(s.resources) == toset([var.bucket_arn, "${var.bucket_arn}/*"])
    ])
    error_message = "El acceso a S3 debe limitarse al bucket y sus objetos."
  }

  assert {
    condition = anytrue([
      for s in data.aws_iam_policy_document.this.statement :
      s.sid == "UseKeyThroughS3AndFirehose" && toset(s.resources) == toset([var.kms_key_arn]) &&
      anytrue([for c in s.condition : c.variable == "kms:ViaService" && toset(c.values) == toset(["s3.us-east-1.amazonaws.com", "firehose.us-east-1.amazonaws.com"])])
    ])
    error_message = "La CMK solo debe usarse a través de S3 y Firehose."
  }

  assert {
    condition = alltrue([
      for s in data.aws_iam_policy_document.this.statement : !contains(s.resources, "*")
    ])
    error_message = "Ninguna sentencia puede usar Resource = *."
  }
}

run "ssm_parameters_are_published_under_integration_layer" {
  command = apply

  assert {
    condition = (
      toset(keys(aws_ssm_parameter.this)) == toset(["firehose_stream_name", "firehose_stream_arn"]) &&
      aws_ssm_parameter.this["firehose_stream_name"].name == "/acme/dev/integration/firehose_stream_name" &&
      alltrue([for p in aws_ssm_parameter.this : p.type == "String"])
    )
    error_message = "Deben publicarse nombre y ARN bajo /<project>/<env>/integration/."
  }
}

run "ssm_publication_can_be_disabled" {
  command = plan

  variables {
    publish_ssm_parameters = false
  }

  assert {
    condition     = length(aws_ssm_parameter.this) == 0
    error_message = "publish_ssm_parameters = false no crea parámetros."
  }
}

run "rejects_small_buffer_with_dynamic_partitioning" {
  command = plan

  variables {
    dynamic_partitioning = { key_name = "tenant_id", jq_query = ".detail.tenant_id" }
  }

  expect_failures = [var.buffer]
}

run "rejects_buffer_interval_above_900" {
  command = plan

  variables {
    buffer = { interval_seconds = 901 }
  }

  expect_failures = [var.buffer]
}

run "rejects_prefix_without_trailing_slash" {
  command = plan

  variables {
    prefix = "events"
  }

  expect_failures = [var.prefix]
}

run "rejects_jq_query_not_starting_with_dot" {
  command = plan

  variables {
    buffer               = { size_mb = 64 }
    dynamic_partitioning = { key_name = "tenant_id", jq_query = "detail.tenant_id" }
  }

  expect_failures = [var.dynamic_partitioning]
}

run "rejects_invalid_partition_key_name" {
  command = plan

  variables {
    buffer               = { size_mb = 64 }
    dynamic_partitioning = { key_name = "Tenant-ID", jq_query = ".detail.tenant_id" }
  }

  expect_failures = [var.dynamic_partitioning]
}

run "rejects_invalid_compression" {
  command = plan

  variables {
    compression_format = "BZIP2"
  }

  expect_failures = [var.compression_format]
}

run "rejects_invalid_bucket_arn" {
  command = plan

  variables {
    bucket_arn = "acme-bucket"
  }

  expect_failures = [var.bucket_arn]
}

run "rejects_alias_as_kms_key" {
  command = plan

  variables {
    kms_key_arn = "arn:aws:kms:us-east-1:123456789012:alias/acme"
  }

  expect_failures = [var.kms_key_arn]
}

run "rejects_prod_with_short_log_retention" {
  command = plan

  variables {
    environment        = "prod"
    log_retention_days = 30
  }

  expect_failures = [var.log_retention_days]
}
