mock_provider "aws" {}

variables {
  project     = "acme"
  environment = "dev"
  kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/11111111-2222-3333-4444-555555555555"
}

run "cluster_has_enhanced_container_insights" {
  command = plan

  assert {
    condition = (
      aws_ecs_cluster.this.name == "acme-dev" &&
      alltrue([for s in aws_ecs_cluster.this.setting : s.name == "containerInsights" && s.value == "enhanced"])
    )
    error_message = "El cluster debe llamarse <project>-<environment> y tener Container Insights enhanced."
  }
}

run "dev_has_exec_with_encrypted_logging_and_spot" {
  command = plan

  assert {
    condition = (
      length(aws_cloudwatch_log_group.exec) == 1 &&
      aws_cloudwatch_log_group.exec[0].name == "/aws/ecs/acme-dev/exec" &&
      aws_cloudwatch_log_group.exec[0].kms_key_id == var.kms_key_arn &&
      aws_cloudwatch_log_group.exec[0].retention_in_days == 90
    )
    error_message = "En dev, ECS Exec registra en un log group cifrado con retención."
  }

  assert {
    condition = alltrue([
      for c in aws_ecs_cluster.this.configuration : alltrue([
        for e in c.execute_command_configuration :
        e.kms_key_id == var.kms_key_arn && e.logging == "OVERRIDE" &&
        alltrue([for l in e.log_configuration : l.cloud_watch_encryption_enabled && l.cloud_watch_log_group_name == "/aws/ecs/acme-dev/exec"])
      ])
    ])
    error_message = "execute_command_configuration debe usar la CMK y el log group cifrado."
  }

  assert {
    condition     = toset(aws_ecs_cluster_capacity_providers.this.capacity_providers) == toset(["FARGATE", "FARGATE_SPOT"])
    error_message = "En dev se admite Spot."
  }
}

run "default_strategy_keeps_a_fargate_base_and_weights_spot" {
  command = plan

  assert {
    condition = alltrue([
      for s in aws_ecs_cluster_capacity_providers.this.default_capacity_provider_strategy :
      s.capacity_provider == "FARGATE" ? (s.base == 1 && s.weight == 1) : (s.capacity_provider == "FARGATE_SPOT" && s.base == 0 && s.weight == 3)
    ]) && length(aws_ecs_cluster_capacity_providers.this.default_capacity_provider_strategy) == 2
    error_message = "FARGATE aporta la base y FARGATE_SPOT el resto con peso 3."
  }
}

run "prod_has_no_exec_and_no_spot_by_default" {
  command = plan

  variables {
    environment = "prod"
  }

  assert {
    condition = (
      length(aws_cloudwatch_log_group.exec) == 0 &&
      output.exec_enabled == false &&
      alltrue([for c in aws_ecs_cluster.this.configuration : length(c.execute_command_configuration) == 0])
    )
    error_message = "En prod ECS Exec está desactivado por defecto."
  }

  assert {
    condition = (
      aws_ecs_cluster_capacity_providers.this.capacity_providers == toset(["FARGATE"]) &&
      length(aws_ecs_cluster_capacity_providers.this.default_capacity_provider_strategy) == 1
    )
    error_message = "En prod solo FARGATE por defecto."
  }
}

run "prod_can_opt_in_to_exec_and_spot" {
  command = plan

  variables {
    environment         = "prod"
    enable_exec         = true
    enable_fargate_spot = true
  }

  assert {
    condition     = length(aws_cloudwatch_log_group.exec) == 1 && toset(aws_ecs_cluster_capacity_providers.this.capacity_providers) == toset(["FARGATE", "FARGATE_SPOT"])
    error_message = "Los valores explícitos mandan sobre el default por entorno."
  }
}

run "dev_can_disable_exec_and_spot" {
  command = plan

  variables {
    enable_exec         = false
    enable_fargate_spot = false
  }

  assert {
    condition     = length(aws_cloudwatch_log_group.exec) == 0 && length(aws_ecs_cluster_capacity_providers.this.capacity_providers) == 1
    error_message = "Los valores explícitos mandan sobre el default por entorno."
  }
}

run "ephemeral_storage_key_is_optional" {
  command = plan

  assert {
    condition     = alltrue([for c in aws_ecs_cluster.this.configuration : length(c.managed_storage_configuration) == 0])
    error_message = "Sin clave, no hay managed_storage_configuration."
  }
}

run "ephemeral_storage_encrypted_with_cmk" {
  command = plan

  variables {
    ephemeral_storage_kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/99999999-2222-3333-4444-555555555555"
  }

  assert {
    condition = alltrue([
      for c in aws_ecs_cluster.this.configuration : alltrue([
        for m in c.managed_storage_configuration :
        m.fargate_ephemeral_storage_kms_key_id == var.ephemeral_storage_kms_key_arn
      ])
    ]) && alltrue([for c in aws_ecs_cluster.this.configuration : length(c.managed_storage_configuration) == 1])
    error_message = "El almacenamiento efímero debe cifrarse con la CMK indicada."
  }
}

run "custom_name_is_used" {
  command = plan

  variables {
    name = "shared"
  }

  assert {
    condition     = aws_ecs_cluster.this.name == "shared" && output.cluster_name == "shared"
    error_message = "name sustituye al nombre por defecto."
  }
}

run "rejects_short_retention_in_prod" {
  command = plan

  variables {
    environment        = "prod"
    log_retention_days = 30
  }

  expect_failures = [var.log_retention_days]
}

run "rejects_invalid_retention_value" {
  command = plan

  variables {
    log_retention_days = 45
  }

  expect_failures = [var.log_retention_days]
}

run "rejects_unknown_container_insights_mode" {
  command = plan

  variables {
    container_insights = "on"
  }

  expect_failures = [var.container_insights]
}

run "rejects_kms_alias" {
  command = plan

  variables {
    kms_key_arn = "arn:aws:kms:us-east-1:123456789012:alias/ecs"
  }

  expect_failures = [var.kms_key_arn]
}

run "container_insights_log_group_is_precreated_with_cmk" {
  command = plan

  assert {
    condition     = length(aws_cloudwatch_log_group.container_insights) == 1 && aws_cloudwatch_log_group.container_insights[0].kms_key_id == var.kms_key_arn
    error_message = "El log group de Container Insights se crea antes que el cluster, cifrado con la CMK."
  }
}

run "no_container_insights_log_group_when_disabled" {
  command = plan

  variables {
    container_insights = "disabled"
  }

  assert {
    condition     = length(aws_cloudwatch_log_group.container_insights) == 0
    error_message = "Sin Container Insights no se crea su log group."
  }
}

run "rejects_disabled_container_insights_in_prod" {
  command = plan

  variables {
    environment        = "prod"
    container_insights = "disabled"
  }

  expect_failures = [var.container_insights]
}
