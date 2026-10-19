mock_provider "aws" {
  mock_resource "aws_dynamodb_table" {
    defaults = {
      arn        = "arn:aws:dynamodb:us-east-1:123456789012:table/acme-dev-orders"
      stream_arn = "arn:aws:dynamodb:us-east-1:123456789012:table/acme-dev-orders/stream/2026-10-05T00:00:00.000"
    }
  }
}

variables {
  project     = "acme"
  environment = "dev"
  name        = "orders"
  kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/11111111-2222-3333-4444-555555555555"
  hash_key    = "pk"
  attributes  = { pk = "S" }
}

run "table_is_on_demand_encrypted_with_cmk_and_has_pitr" {
  command = plan

  assert {
    condition = (
      aws_dynamodb_table.this.name == "acme-dev-orders" &&
      aws_dynamodb_table.this.billing_mode == "PAY_PER_REQUEST" &&
      aws_dynamodb_table.this.hash_key == "pk" &&
      aws_dynamodb_table.this.table_class == "STANDARD"
    )
    error_message = "La tabla debe llamarse <project>-<env>-<name> y ser PAY_PER_REQUEST con clase STANDARD por defecto."
  }

  assert {
    condition = (
      alltrue([for s in aws_dynamodb_table.this.server_side_encryption : s.enabled == true && s.kms_key_arn == var.kms_key_arn]) &&
      length(aws_dynamodb_table.this.server_side_encryption) == 1
    )
    error_message = "SSE debe estar activo con la CMK del entorno."
  }

  assert {
    condition     = alltrue([for p in aws_dynamodb_table.this.point_in_time_recovery : p.enabled == true]) && length(aws_dynamodb_table.this.point_in_time_recovery) == 1
    error_message = "PITR debe estar siempre activo."
  }
}

run "dev_defaults_are_relaxed_but_safe" {
  command = plan

  assert {
    condition = (
      aws_dynamodb_table.this.deletion_protection_enabled == false &&
      alltrue([for p in aws_dynamodb_table.this.point_in_time_recovery : p.recovery_period_in_days == 7])
    )
    error_message = "dev: sin protección de borrado y PITR de 7 días."
  }
}

run "staging_keeps_deletion_protection" {
  command = plan

  variables {
    environment = "staging"
  }

  assert {
    condition     = aws_dynamodb_table.this.deletion_protection_enabled == true
    error_message = "Fuera de dev la protección contra borrado debe estar activa por defecto."
  }
}

run "prod_defaults_are_strict" {
  command = plan

  variables {
    environment = "prod"
  }

  assert {
    condition = (
      aws_dynamodb_table.this.deletion_protection_enabled == true &&
      alltrue([for p in aws_dynamodb_table.this.point_in_time_recovery : p.recovery_period_in_days == 35])
    )
    error_message = "prod: protección de borrado y PITR de 35 días."
  }
}

run "provisioned_mode_sets_capacity_on_table_and_indexes" {
  command = plan

  variables {
    billing_mode         = "PROVISIONED"
    provisioned_capacity = { read = 5, write = 3 }
    attributes           = { pk = "S", gsi_pk = "S" }
    global_secondary_indexes = {
      by-gsi = { hash_key = "gsi_pk" }
    }
  }

  assert {
    condition = (
      aws_dynamodb_table.this.read_capacity == 5 &&
      aws_dynamodb_table.this.write_capacity == 3 &&
      alltrue([for g in aws_dynamodb_table.this.global_secondary_index : g.read_capacity == 5 && g.write_capacity == 3])
    )
    error_message = "En PROVISIONED la capacidad aplica a la tabla y a sus índices globales."
  }
}

run "indexes_are_created_from_maps_with_stable_names" {
  command = plan

  variables {
    range_key  = "sk"
    attributes = { pk = "S", sk = "S", status = "S", created_at = "N", channel = "S" }

    global_secondary_indexes = {
      by-status = { hash_key = "pk", range_key = "status", projection_type = "INCLUDE", non_key_attributes = ["total"] }
      by-date   = { hash_key = "pk", range_key = "created_at" }
    }

    local_secondary_indexes = {
      by-channel = { range_key = "channel", projection_type = "KEYS_ONLY" }
    }
  }

  assert {
    condition     = toset([for g in aws_dynamodb_table.this.global_secondary_index : g.name]) == toset(["by-status", "by-date"])
    error_message = "Debe crearse un índice global por entrada del mapa."
  }

  assert {
    condition = (
      toset([for g in aws_dynamodb_table.this.global_secondary_index : g.projection_type if g.name == "by-status"]) == toset(["INCLUDE"]) &&
      toset(flatten([for g in aws_dynamodb_table.this.global_secondary_index : g.non_key_attributes if g.name == "by-status"])) == toset(["total"]) &&
      toset([for g in aws_dynamodb_table.this.global_secondary_index : g.projection_type if g.name == "by-date"]) == toset(["ALL"])
    )
    error_message = "Las proyecciones de los índices globales no coinciden con la configuración."
  }

  assert {
    condition = (
      toset(flatten([for g in aws_dynamodb_table.this.global_secondary_index : [for k in g.key_schema : "${k.attribute_name}:${k.key_type}"] if g.name == "by-status"])) == toset(["pk:HASH", "status:RANGE"]) &&
      toset(flatten([for g in aws_dynamodb_table.this.global_secondary_index : [for k in g.key_schema : "${k.attribute_name}:${k.key_type}"] if g.name == "by-date"])) == toset(["pk:HASH", "created_at:RANGE"])
    )
    error_message = "Cada índice global debe declarar su clave de partición (HASH) y de ordenación (RANGE) con key_schema."
  }

  assert {
    condition     = toset([for l in aws_dynamodb_table.this.local_secondary_index : l.name]) == toset(["by-channel"])
    error_message = "Debe crearse el índice local."
  }

  assert {
    condition     = toset([for a in aws_dynamodb_table.this.attribute : a.name]) == toset(["pk", "sk", "status", "created_at", "channel"])
    error_message = "Deben declararse exactamente los atributos clave."
  }
}

run "ttl_is_optional" {
  command = plan

  assert {
    condition     = length(aws_dynamodb_table.this.ttl) == 0
    error_message = "Sin ttl_attribute no debe haber TTL."
  }
}

run "ttl_is_enabled_on_the_given_attribute" {
  command = plan

  variables {
    ttl_attribute = "expires_at"
  }

  assert {
    condition     = alltrue([for t in aws_dynamodb_table.this.ttl : t.enabled == true && t.attribute_name == "expires_at"]) && length(aws_dynamodb_table.this.ttl) == 1
    error_message = "El TTL debe activarse sobre el atributo indicado."
  }
}

run "streams_are_off_by_default" {
  command = plan

  assert {
    condition     = aws_dynamodb_table.this.stream_enabled == false
    error_message = "Los streams deben estar desactivados por defecto."
  }
}

run "streams_can_be_enabled_with_view_type" {
  command = plan

  variables {
    stream_view_type = "NEW_AND_OLD_IMAGES"
  }

  assert {
    condition     = aws_dynamodb_table.this.stream_enabled == true && aws_dynamodb_table.this.stream_view_type == "NEW_AND_OLD_IMAGES"
    error_message = "stream_view_type debe activar el stream con ese contenido."
  }
}

run "contributor_insights_is_opt_in" {
  command = plan

  assert {
    condition     = length(aws_dynamodb_contributor_insights.this) == 0
    error_message = "Contributor Insights tiene coste: debe ser opt-in."
  }
}

run "contributor_insights_can_be_enabled" {
  command = plan

  variables {
    enable_contributor_insights = true
  }

  assert {
    condition     = length(aws_dynamodb_contributor_insights.this) == 1
    error_message = "enable_contributor_insights = true debe crear el recurso."
  }
}

run "tenant_table_uses_tenant_id_partition_key" {
  command = plan

  variables {
    tenant_partition_key = true
    hash_key             = "tenant_id"
    range_key            = "order_id"
    attributes           = { tenant_id = "S", order_id = "S" }
  }

  assert {
    condition     = aws_dynamodb_table.this.hash_key == "tenant_id" && aws_dynamodb_table.this.range_key == "order_id"
    error_message = "La tabla multi-tenant debe particionar por tenant_id."
  }

  assert {
    condition     = aws_dynamodb_table.this.tags["TenantIsolation"] == "partition-key"
    error_message = "La tabla multi-tenant debe llevar la etiqueta TenantIsolation para auditar LeadingKeys."
  }
}

run "regular_table_has_no_tenant_isolation_tag" {
  command = plan

  assert {
    condition     = !contains(keys(aws_dynamodb_table.this.tags), "TenantIsolation")
    error_message = "Una tabla sin tenant_partition_key no debe llevar la etiqueta TenantIsolation."
  }
}

run "iam_outputs_cover_table_and_indexes" {
  command = apply

  variables {
    attributes = { pk = "S", gsi_pk = "S" }
    global_secondary_indexes = {
      by-gsi = { hash_key = "gsi_pk" }
    }
  }

  assert {
    condition = (
      output.iam_resource_arns == ["arn:aws:dynamodb:us-east-1:123456789012:table/acme-dev-orders", "arn:aws:dynamodb:us-east-1:123456789012:table/acme-dev-orders/index/*"] &&
      output.index_arns["by-gsi"] == "arn:aws:dynamodb:us-east-1:123456789012:table/acme-dev-orders/index/by-gsi"
    )
    error_message = "Las salidas IAM deben cubrir la tabla y todos sus índices."
  }
}

run "stream_arn_output_is_null_without_streams" {
  command = apply

  assert {
    condition     = output.stream_arn == null
    error_message = "Sin streams, stream_arn debe ser null."
  }
}

run "ssm_parameters_are_published_under_data_layer" {
  command = apply

  assert {
    condition     = toset(keys(aws_ssm_parameter.this)) == toset(["table_name", "table_arn"])
    error_message = "Sin streams solo se publican el nombre y el ARN."
  }

  assert {
    condition = (
      aws_ssm_parameter.this["table_name"].name == "/acme/dev/data/dynamodb/orders/table_name" &&
      alltrue([for p in aws_ssm_parameter.this : p.type == "String"])
    )
    error_message = "Los parámetros viven en /<project>/<env>/data/dynamodb/<name>/<clave> y no son SecureString (no hay secretos)."
  }
}

run "ssm_publishes_stream_arn_when_streams_are_on" {
  command = apply

  variables {
    stream_view_type = "KEYS_ONLY"
  }

  assert {
    condition     = contains(keys(aws_ssm_parameter.this), "stream_arn")
    error_message = "Con streams debe publicarse también stream_arn."
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

run "rejects_tenant_flag_with_other_hash_key" {
  command = plan

  variables {
    tenant_partition_key = true
  }

  expect_failures = [var.tenant_partition_key]
}

run "rejects_hash_key_missing_from_attributes" {
  command = plan

  variables {
    hash_key = "id"
  }

  expect_failures = [var.attributes]
}

run "rejects_unused_attribute" {
  command = plan

  variables {
    attributes = { pk = "S", extra = "S" }
  }

  expect_failures = [var.attributes]
}

run "rejects_invalid_attribute_type" {
  command = plan

  variables {
    attributes = { pk = "X" }
  }

  expect_failures = [var.attributes]
}

run "rejects_index_key_missing_from_attributes" {
  command = plan

  variables {
    global_secondary_indexes = {
      by-gsi = { hash_key = "gsi_pk" }
    }
  }

  expect_failures = [var.attributes]
}

run "rejects_include_projection_without_attributes" {
  command = plan

  variables {
    global_secondary_indexes = {
      by-pk = { hash_key = "pk", projection_type = "INCLUDE" }
    }
  }

  expect_failures = [var.global_secondary_indexes]
}

run "rejects_local_index_without_range_key" {
  command = plan

  variables {
    attributes = { pk = "S", other = "S" }
    local_secondary_indexes = {
      by-other = { range_key = "other" }
    }
  }

  expect_failures = [var.local_secondary_indexes]
}

run "rejects_provisioned_without_capacity" {
  command = plan

  variables {
    billing_mode = "PROVISIONED"
  }

  expect_failures = [var.provisioned_capacity]
}

run "rejects_capacity_with_on_demand" {
  command = plan

  variables {
    provisioned_capacity = { read = 1, write = 1 }
  }

  expect_failures = [var.provisioned_capacity]
}

run "rejects_prod_without_deletion_protection" {
  command = plan

  variables {
    environment         = "prod"
    deletion_protection = false
  }

  expect_failures = [var.deletion_protection]
}

run "rejects_prod_with_short_pitr_window" {
  command = plan

  variables {
    environment                 = "prod"
    point_in_time_recovery_days = 7
  }

  expect_failures = [var.point_in_time_recovery_days]
}

run "rejects_alias_as_kms_key" {
  command = plan

  variables {
    kms_key_arn = "arn:aws:kms:us-east-1:123456789012:alias/acme"
  }

  expect_failures = [var.kms_key_arn]
}

run "rejects_invalid_stream_view_type" {
  command = plan

  variables {
    stream_view_type = "ALL_IMAGES"
  }

  expect_failures = [var.stream_view_type]
}
