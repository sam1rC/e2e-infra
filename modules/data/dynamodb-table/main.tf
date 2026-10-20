resource "aws_dynamodb_table" "this" {
  name           = local.table_name
  billing_mode   = var.billing_mode
  read_capacity  = local.provisioned ? var.provisioned_capacity.read : null
  write_capacity = local.provisioned ? var.provisioned_capacity.write : null
  table_class    = var.table_class
  hash_key       = var.hash_key
  range_key      = var.range_key

  deletion_protection_enabled = local.deletion_protection

  stream_enabled   = var.stream_view_type != null
  stream_view_type = var.stream_view_type

  dynamic "attribute" {
    for_each = var.attributes

    content {
      name = attribute.key
      type = attribute.value
    }
  }

  dynamic "global_secondary_index" {
    for_each = var.global_secondary_indexes

    content {
      name               = global_secondary_index.key
      projection_type    = global_secondary_index.value.projection_type
      non_key_attributes = global_secondary_index.value.projection_type == "INCLUDE" ? global_secondary_index.value.non_key_attributes : null
      read_capacity      = local.provisioned ? var.provisioned_capacity.read : null
      write_capacity     = local.provisioned ? var.provisioned_capacity.write : null

      # hash_key/range_key dentro del índice están deprecados desde el provider 6.x en favor de key_schema.
      key_schema {
        attribute_name = global_secondary_index.value.hash_key
        key_type       = "HASH"
      }

      dynamic "key_schema" {
        for_each = global_secondary_index.value.range_key == null ? [] : [global_secondary_index.value.range_key]

        content {
          attribute_name = key_schema.value
          key_type       = "RANGE"
        }
      }
    }
  }

  dynamic "local_secondary_index" {
    for_each = var.local_secondary_indexes

    content {
      name               = local_secondary_index.key
      range_key          = local_secondary_index.value.range_key
      projection_type    = local_secondary_index.value.projection_type
      non_key_attributes = local_secondary_index.value.projection_type == "INCLUDE" ? local_secondary_index.value.non_key_attributes : null
    }
  }

  point_in_time_recovery {
    enabled                 = true
    recovery_period_in_days = local.pitr_days
  }

  # enabled = true con kms_key_arn cifra con la CMK; sin ella DynamoDB usaría una clave propiedad de AWS.
  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  dynamic "ttl" {
    for_each = var.ttl_attribute == null ? [] : [var.ttl_attribute]

    content {
      attribute_name = ttl.value
      enabled        = true
    }
  }

  # La etiqueta permite auditar qué tablas deben aplicar dynamodb:LeadingKeys (fase 8.3).
  tags = merge(var.tags, { Name = local.table_name }, var.tenant_partition_key ? { TenantIsolation = "partition-key" } : null)
}

resource "aws_dynamodb_contributor_insights" "this" {
  count = var.enable_contributor_insights ? 1 : 0

  table_name = aws_dynamodb_table.this.name
}
