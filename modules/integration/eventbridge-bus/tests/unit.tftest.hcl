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

  # Un JSON válido: aws_iam_role y las políticas rechazan el texto aleatorio que genera el mock.
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/acme-dev-events-fh"
    }
  }

  mock_resource "aws_cloudwatch_event_bus" {
    defaults = {
      arn = "arn:aws:events:us-east-1:123456789012:event-bus/acme-dev-events"
    }
  }

  mock_resource "aws_cloudwatch_event_rule" {
    defaults = {
      arn = "arn:aws:events:us-east-1:123456789012:rule/acme-dev-events/acme-dev-events-orders"
    }
  }

  mock_resource "aws_sqs_queue" {
    defaults = {
      arn = "arn:aws:sqs:us-east-1:123456789012:acme-dev-events-orders-dlq"
      url = "https://sqs.us-east-1.amazonaws.com/123456789012/acme-dev-events-orders-dlq"
    }
  }
}

variables {
  project     = "acme"
  environment = "dev"
  kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/11111111-2222-3333-4444-555555555555"
}

run "bus_is_named_and_encrypted_with_cmk" {
  command = plan

  assert {
    condition = (
      aws_cloudwatch_event_bus.this.name == "acme-dev-events" &&
      aws_cloudwatch_event_bus.this.kms_key_identifier == var.kms_key_arn
    )
    error_message = "El bus debe llamarse <project>-<env>-events y cifrarse con la CMK."
  }
}

run "archive_keeps_events_for_replay" {
  command = plan

  assert {
    condition = (
      length(aws_cloudwatch_event_archive.this) == 1 &&
      aws_cloudwatch_event_archive.this[0].retention_days == 30 &&
      aws_cloudwatch_event_archive.this[0].kms_key_identifier == var.kms_key_arn
    )
    error_message = "El archivo debe conservar 30 días por defecto y cifrarse con la CMK."
  }
}

run "archive_can_be_disabled_outside_prod" {
  command = plan

  variables {
    archive_retention_days = 0
  }

  assert {
    condition     = length(aws_cloudwatch_event_archive.this) == 0
    error_message = "archive_retention_days = 0 no debe crear archivo."
  }
}

run "without_rules_there_is_no_role_queue_or_target" {
  command = plan

  assert {
    condition = (
      length(aws_cloudwatch_event_rule.this) == 0 &&
      length(aws_cloudwatch_event_target.firehose) == 0 &&
      length(aws_sqs_queue.dlq) == 0 &&
      length(aws_iam_role.events_to_firehose) == 0
    )
    error_message = "Sin reglas no debe crearse ni rol, ni DLQ, ni destinos."
  }
}

run "source_prefixes_build_an_eventbridge_prefix_pattern" {
  command = plan

  variables {
    rules = {
      orders = {
        firehose_arn    = "arn:aws:firehose:us-east-1:123456789012:deliverystream/acme-dev-orders"
        source_prefixes = ["orders."]
      }
    }
  }

  assert {
    condition = (
      aws_cloudwatch_event_rule.this["orders"].name == "acme-dev-events-orders" &&
      aws_cloudwatch_event_rule.this["orders"].event_bus_name == "acme-dev-events" &&
      jsondecode(aws_cloudwatch_event_rule.this["orders"].event_pattern).source[0].prefix == "orders." &&
      !contains(keys(jsondecode(aws_cloudwatch_event_rule.this["orders"].event_pattern)), "detail-type")
    )
    error_message = "source_prefixes debe generar {source:[{prefix:...}]} sin detail-type."
  }
}

run "detail_type_prefixes_build_a_detail_type_pattern" {
  command = plan

  variables {
    rules = {
      usage = {
        firehose_arn         = "arn:aws:firehose:us-east-1:123456789012:deliverystream/acme-dev-usage"
        detail_type_prefixes = ["usage."]
      }
    }
  }

  assert {
    condition = (
      jsondecode(aws_cloudwatch_event_rule.this["usage"].event_pattern)["detail-type"][0].prefix == "usage." &&
      !contains(keys(jsondecode(aws_cloudwatch_event_rule.this["usage"].event_pattern)), "source")
    )
    error_message = "detail_type_prefixes debe generar {detail-type:[{prefix:...}]} sin source."
  }
}

run "custom_event_pattern_is_passed_through" {
  command = plan

  variables {
    rules = {
      custom = {
        firehose_arn  = "arn:aws:firehose:us-east-1:123456789012:deliverystream/acme-dev-custom"
        event_pattern = "{\"source\":[\"acme.billing\"],\"detail-type\":[\"Invoice Paid\"]}"
      }
    }
  }

  assert {
    condition     = jsondecode(aws_cloudwatch_event_rule.this["custom"].event_pattern).source[0] == "acme.billing"
    error_message = "event_pattern debe usarse tal cual."
  }
}

run "targets_use_retry_policy_and_a_dlq_per_rule" {
  command = plan

  variables {
    retry_policy = { maximum_retry_attempts = 10, maximum_event_age_in_seconds = 1800 }
    rules = {
      orders = {
        firehose_arn    = "arn:aws:firehose:us-east-1:123456789012:deliverystream/acme-dev-orders"
        source_prefixes = ["orders."]
      }
      usage = {
        firehose_arn         = "arn:aws:firehose:us-east-1:123456789012:deliverystream/acme-dev-usage"
        detail_type_prefixes = ["usage."]
      }
    }
  }

  assert {
    condition = (
      toset(keys(aws_cloudwatch_event_target.firehose)) == toset(["orders", "usage"]) &&
      aws_cloudwatch_event_target.firehose["orders"].arn == "arn:aws:firehose:us-east-1:123456789012:deliverystream/acme-dev-orders" &&
      length(aws_cloudwatch_event_target.firehose["orders"].retry_policy) == 1 &&
      alltrue([for r in aws_cloudwatch_event_target.firehose["orders"].retry_policy : r.maximum_retry_attempts == 10 && r.maximum_event_age_in_seconds == 1800])
    )
    error_message = "Cada regla debe tener su destino Firehose con los reintentos configurados."
  }

  assert {
    condition = (
      toset(keys(aws_sqs_queue.dlq)) == toset(["orders", "usage"]) &&
      length(aws_cloudwatch_event_target.firehose["usage"].dead_letter_config) == 1
    )
    error_message = "Cada destino debe tener su propia DLQ."
  }
}

run "dlqs_are_cmk_encrypted_with_retention_and_tls_only_policy" {
  command = plan

  variables {
    dlq_retention_days = 7
    rules = {
      orders = {
        firehose_arn    = "arn:aws:firehose:us-east-1:123456789012:deliverystream/acme-dev-orders"
        source_prefixes = ["orders."]
      }
    }
  }

  assert {
    condition = (
      aws_sqs_queue.dlq["orders"].name == "acme-dev-events-orders-dlq" &&
      aws_sqs_queue.dlq["orders"].kms_master_key_id == var.kms_key_arn &&
      aws_sqs_queue.dlq["orders"].message_retention_seconds == 7 * 86400
    )
    error_message = "Las DLQ deben cifrarse con la CMK y conservar los días indicados."
  }

  assert {
    condition = (
      length(data.aws_iam_policy_document.dlq["orders"].statement) == 2 &&
      toset([for s in data.aws_iam_policy_document.dlq["orders"].statement : s.sid]) == toset(["AllowEventBridgeRuleToSend", "DenyInsecureTransport"]) &&
      anytrue([for s in data.aws_iam_policy_document.dlq["orders"].statement : s.sid == "DenyInsecureTransport" && s.effect == "Deny"])
    )
    error_message = "La política de la DLQ debe permitir solo a su regla y denegar el transporte sin TLS."
  }
}

run "role_can_only_put_records_to_the_declared_streams" {
  command = plan

  variables {
    rules = {
      orders = {
        firehose_arn    = "arn:aws:firehose:us-east-1:123456789012:deliverystream/acme-dev-shared"
        source_prefixes = ["orders."]
      }
      returns = {
        firehose_arn    = "arn:aws:firehose:us-east-1:123456789012:deliverystream/acme-dev-shared"
        source_prefixes = ["returns."]
      }
    }
  }

  assert {
    condition = (
      length(aws_iam_role.events_to_firehose) == 1 &&
      length(data.aws_iam_policy_document.events_to_firehose.statement) == 1 &&
      alltrue([
        for s in data.aws_iam_policy_document.events_to_firehose.statement :
        toset(s.actions) == toset(["firehose:PutRecord", "firehose:PutRecordBatch"]) &&
        s.resources == toset(["arn:aws:firehose:us-east-1:123456789012:deliverystream/acme-dev-shared"])
      ])
    )
    error_message = "El rol solo debe poder escribir en los streams declarados (sin duplicados), con solo PutRecord y PutRecordBatch."
  }
}

run "target_stream_keys_add_a_kms_statement_via_firehose" {
  command = plan

  variables {
    target_kms_key_arns = ["arn:aws:kms:us-east-1:123456789012:key/aaaaaaaa-2222-3333-4444-555555555555"]
    rules = {
      orders = {
        firehose_arn    = "arn:aws:firehose:us-east-1:123456789012:deliverystream/acme-dev-orders"
        source_prefixes = ["orders."]
      }
    }
  }

  assert {
    condition = anytrue([
      for s in data.aws_iam_policy_document.events_to_firehose.statement :
      s.sid == "UseTargetStreamKeys" &&
      anytrue([for c in s.condition : c.variable == "kms:ViaService" && toset(c.values) == toset(["firehose.us-east-1.amazonaws.com"])])
    ])
    error_message = "Las claves de los streams destino solo deben usarse a través de Firehose."
  }
}

run "trust_is_limited_to_the_buses_rules_in_this_account" {
  command = plan

  variables {
    rules = {
      orders = {
        firehose_arn    = "arn:aws:firehose:us-east-1:123456789012:deliverystream/acme-dev-orders"
        source_prefixes = ["orders."]
      }
    }
  }

  assert {
    condition = alltrue([
      for s in data.aws_iam_policy_document.events_assume.statement :
      toset([for c in s.condition : "${c.variable}=${join(",", c.values)}"]) == toset([
        "aws:SourceAccount=123456789012",
        "aws:SourceArn=arn:aws:events:us-east-1:123456789012:rule/acme-dev-events/acme-dev-events-orders",
      ])
    ])
    error_message = "El trust del rol debe limitarse a events.amazonaws.com, esta cuenta y las reglas del bus."
  }
}

run "other_accounts_can_publish_only_when_listed" {
  command = plan

  assert {
    condition     = length(aws_cloudwatch_event_bus_policy.publishers) == 0
    error_message = "Sin publisher_account_ids no debe haber política de bus."
  }
}

run "listed_accounts_get_put_events_on_the_bus" {
  command = plan

  variables {
    publisher_account_ids = ["210987654321"]
  }

  assert {
    condition = (
      length(aws_cloudwatch_event_bus_policy.publishers) == 1 &&
      alltrue([
        for s in data.aws_iam_policy_document.publishers[0].statement :
        toset(s.actions) == toset(["events:PutEvents"])
      ])
    )
    error_message = "Las cuentas listadas solo deben poder hacer events:PutEvents."
  }
}

run "ssm_parameters_are_published_under_integration_layer" {
  command = apply

  assert {
    condition = (
      toset(keys(aws_ssm_parameter.this)) == toset(["event_bus_name", "event_bus_arn"]) &&
      aws_ssm_parameter.this["event_bus_name"].name == "/acme/dev/integration/event_bus_name" &&
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

run "rejects_rule_with_both_pattern_styles" {
  command = plan

  variables {
    rules = {
      orders = {
        firehose_arn    = "arn:aws:firehose:us-east-1:123456789012:deliverystream/acme-dev-orders"
        source_prefixes = ["orders."]
        event_pattern   = "{\"source\":[\"x\"]}"
      }
    }
  }

  expect_failures = [var.rules]
}

run "rejects_rule_without_any_pattern" {
  command = plan

  variables {
    rules = {
      orders = {
        firehose_arn = "arn:aws:firehose:us-east-1:123456789012:deliverystream/acme-dev-orders"
      }
    }
  }

  expect_failures = [var.rules]
}

run "rejects_invalid_json_pattern" {
  command = plan

  variables {
    rules = {
      orders = {
        firehose_arn  = "arn:aws:firehose:us-east-1:123456789012:deliverystream/acme-dev-orders"
        event_pattern = "{not json"
      }
    }
  }

  expect_failures = [var.rules]
}

run "rejects_target_that_is_not_a_firehose_stream" {
  command = plan

  variables {
    rules = {
      orders = {
        firehose_arn    = "arn:aws:s3:::acme-bucket"
        source_prefixes = ["orders."]
      }
    }
  }

  expect_failures = [var.rules]
}

run "rejects_rule_key_with_uppercase" {
  command = plan

  variables {
    rules = {
      Orders = {
        firehose_arn    = "arn:aws:firehose:us-east-1:123456789012:deliverystream/acme-dev-orders"
        source_prefixes = ["orders."]
      }
    }
  }

  expect_failures = [var.rules]
}

run "rejects_retry_attempts_above_185" {
  command = plan

  variables {
    retry_policy = { maximum_retry_attempts = 186 }
  }

  expect_failures = [var.retry_policy]
}

run "rejects_prod_without_enough_archive" {
  command = plan

  variables {
    environment            = "prod"
    archive_retention_days = 3
  }

  expect_failures = [var.archive_retention_days]
}

run "rejects_invalid_publisher_account" {
  command = plan

  variables {
    publisher_account_ids = ["not-an-account"]
  }

  expect_failures = [var.publisher_account_ids]
}

run "rejects_alias_as_kms_key" {
  command = plan

  variables {
    kms_key_arn = "arn:aws:kms:us-east-1:123456789012:alias/acme"
  }

  expect_failures = [var.kms_key_arn]
}
