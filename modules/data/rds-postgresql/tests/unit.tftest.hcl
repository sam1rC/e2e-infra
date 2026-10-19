mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition  = "aws"
      dns_suffix = "amazonaws.com"
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

  mock_resource "aws_db_instance" {
    defaults = {
      arn         = "arn:aws:rds:us-east-1:123456789012:db:acme-dev-postgres"
      address     = "acme-dev-postgres.abc.us-east-1.rds.amazonaws.com"
      resource_id = "db-ABCDEFGHIJKLMNOPQRSTUVWXYZ"
      master_user_secret = [{
        kms_key_id    = "arn:aws:kms:us-east-1:123456789012:key/11111111-2222-3333-4444-555555555555"
        secret_arn    = "arn:aws:secretsmanager:us-east-1:123456789012:secret:rds!db-abc-AbCdEf"
        secret_status = "active"
      }]
    }
  }

  mock_resource "aws_security_group" {
    defaults = {
      id = "sg-0123456789abcdef0"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/acme-dev-postgres-mon"
    }
  }

  mock_resource "aws_cloudformation_stack" {
    defaults = {
      outputs = {
        RotationLambdaARN = "arn:aws:lambda:us-east-1:123456789012:function:acme-dev-postgres-rotation"
      }
    }
  }
}

variables {
  project        = "acme"
  environment    = "dev"
  vpc_id         = "vpc-0123456789abcdef0"
  subnet_ids     = ["subnet-0aaaaaaaaaaaaaaaa", "subnet-0bbbbbbbbbbbbbbbb"]
  kms_key_arn    = "arn:aws:kms:us-east-1:123456789012:key/11111111-2222-3333-4444-555555555555"
  engine_version = "17.11"

  allowed_security_group_ids = {
    app    = "sg-0aaaaaaaaaaaaaaaa"
    worker = "sg-0bbbbbbbbbbbbbbbb"
  }
}

run "parameter_group_enforces_tls_logging_and_pgaudit" {
  command = plan

  assert {
    condition     = aws_db_parameter_group.this.family == "postgres17"
    error_message = "La familia del parameter group debe deducirse de la versión mayor."
  }

  assert {
    condition = (
      { for p in aws_db_parameter_group.this.parameter : p.name => p.value }["rds.force_ssl"] == "1" &&
      { for p in aws_db_parameter_group.this.parameter : p.name => p.value }["log_connections"] == "1" &&
      { for p in aws_db_parameter_group.this.parameter : p.name => p.value }["log_disconnections"] == "1" &&
      { for p in aws_db_parameter_group.this.parameter : p.name => p.value }["log_min_duration_statement"] == "1000" &&
      { for p in aws_db_parameter_group.this.parameter : p.name => p.value }["shared_preload_libraries"] == "pg_stat_statements,pgaudit" &&
      { for p in aws_db_parameter_group.this.parameter : p.name => p.value }["pgaudit.log"] == "ddl,role"
    )
    error_message = "El parameter group debe forzar TLS, registrar conexiones y lentas y cargar pgaudit con ddl,role."
  }

  assert {
    condition     = alltrue([for p in aws_db_parameter_group.this.parameter : p.apply_method == "pending-reboot" if p.name == "shared_preload_libraries"])
    error_message = "shared_preload_libraries es estático: debe aplicarse con pending-reboot."
  }
}

run "postgresql_log_group_is_precreated_with_cmk_and_retention" {
  command = plan

  variables {
    log_retention_days = 30
  }

  assert {
    condition = (
      aws_cloudwatch_log_group.postgresql.name == "/aws/rds/instance/acme-dev-postgres/postgresql" &&
      aws_cloudwatch_log_group.postgresql.retention_in_days == 30 &&
      aws_cloudwatch_log_group.postgresql.kms_key_id == var.kms_key_arn
    )
    error_message = "RDS crearía el log group sin retención ni cifrado: debe existir antes, con la CMK."
  }
}

run "staging_keeps_deletion_protection" {
  command = plan

  variables {
    environment = "staging"
  }

  assert {
    condition     = aws_db_instance.this.deletion_protection == true
    error_message = "Fuera de dev la protección contra borrado debe estar activa por defecto."
  }
}

run "security_group_admits_only_declared_groups_on_postgres_port" {
  command = plan

  assert {
    condition     = toset(keys(aws_vpc_security_group_ingress_rule.from_allowed)) == toset(["app", "worker"])
    error_message = "Debe haber una regla de entrada por cada SG autorizado."
  }

  assert {
    condition = alltrue([
      for r in aws_vpc_security_group_ingress_rule.from_allowed :
      r.from_port == 5432 && r.to_port == 5432 && r.ip_protocol == "tcp" && r.cidr_ipv4 == null && r.cidr_ipv6 == null
    ])
    error_message = "Las reglas de entrada deben ser TCP 5432 por referencia de SG, nunca por CIDR."
  }
}

run "enhanced_monitoring_role_is_scoped_to_account" {
  command = plan

  assert {
    condition     = length(aws_iam_role.monitoring) == 1 && length(aws_iam_role_policy.monitoring) == 1
    error_message = "Con monitoring_interval > 0 debe crearse el rol de Enhanced Monitoring."
  }
}

run "monitoring_can_be_disabled_outside_prod" {
  command = plan

  variables {
    monitoring_interval = 0
  }

  assert {
    condition     = length(aws_iam_role.monitoring) == 0 && length(aws_iam_role_policy.monitoring) == 0
    error_message = "Con monitoring_interval = 0 no debe haber rol de Enhanced Monitoring."
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

run "app_secret_is_separate_from_master_and_empty" {
  command = apply

  assert {
    condition = (
      module.app_secret.secret_name == "acme-dev-postgres/app_runtime" &&
      module.app_secret.rotation_lambda_arn == null &&
      output.master_user_secret_arn != output.app_secret_arn
    )
    error_message = "El secreto de la aplicación es distinto del maestro, vacío y sin rotación si no se configura."
  }
}

run "rotation_is_wired_to_the_database_security_group" {
  command = apply

  variables {
    app_secret_rotation = {
      subnet_ids                 = ["subnet-0cccccccccccccccc", "subnet-0dddddddddddddddd"]
      endpoint_security_group_id = "sg-0eeeeeeeeeeeeeeee"
    }
  }

  assert {
    condition     = module.app_secret.rotation_lambda_arn == "arn:aws:lambda:us-east-1:123456789012:function:acme-dev-postgres-rotation"
    error_message = "La función de rotación debe desplegarse y exponerse."
  }
}

run "rejects_prod_without_deletion_protection" {
  command = plan

  variables {
    app_secret_rotation = {
      subnet_ids                 = ["subnet-0cccccccccccccccc", "subnet-0dddddddddddddddd"]
      endpoint_security_group_id = "sg-0eeeeeeeeeeeeeeee"
    }
    environment         = "prod"
    deletion_protection = false
  }

  expect_failures = [var.deletion_protection]
}

run "rejects_prod_skipping_final_snapshot" {
  command = plan

  variables {
    app_secret_rotation = {
      subnet_ids                 = ["subnet-0cccccccccccccccc", "subnet-0dddddddddddddddd"]
      endpoint_security_group_id = "sg-0eeeeeeeeeeeeeeee"
    }
    environment         = "prod"
    skip_final_snapshot = true
  }

  expect_failures = [var.skip_final_snapshot]
}

run "rejects_prod_with_short_backup_retention" {
  command = plan

  variables {
    app_secret_rotation = {
      subnet_ids                 = ["subnet-0cccccccccccccccc", "subnet-0dddddddddddddddd"]
      endpoint_security_group_id = "sg-0eeeeeeeeeeeeeeee"
    }
    environment = "prod"
    backup      = { retention_days = 7 }
  }

  expect_failures = [var.backup]
}

run "rejects_prod_without_enhanced_monitoring" {
  command = plan

  variables {
    app_secret_rotation = {
      subnet_ids                 = ["subnet-0cccccccccccccccc", "subnet-0dddddddddddddddd"]
      endpoint_security_group_id = "sg-0eeeeeeeeeeeeeeee"
    }
    environment         = "prod"
    monitoring_interval = 0
  }

  expect_failures = [var.monitoring_interval]
}

run "rejects_prod_with_short_log_retention" {
  command = plan

  variables {
    app_secret_rotation = {
      subnet_ids                 = ["subnet-0cccccccccccccccc", "subnet-0dddddddddddddddd"]
      endpoint_security_group_id = "sg-0eeeeeeeeeeeeeeee"
    }
    environment        = "prod"
    log_retention_days = 30
  }

  expect_failures = [var.log_retention_days]
}

run "rejects_single_subnet" {
  command = plan

  variables {
    subnet_ids = ["subnet-0aaaaaaaaaaaaaaaa"]
  }

  expect_failures = [var.subnet_ids]
}

run "rejects_invalid_engine_version" {
  command = plan

  variables {
    engine_version = "latest"
  }

  expect_failures = [var.engine_version]
}

run "rejects_default_postgres_master_username" {
  command = plan

  variables {
    master_username = "postgres"
  }

  expect_failures = [var.master_username]
}

run "rejects_alias_as_kms_key" {
  command = plan

  variables {
    kms_key_arn = "arn:aws:kms:us-east-1:123456789012:alias/acme"
  }

  expect_failures = [var.kms_key_arn]
}

run "rejects_invalid_backup_window" {
  command = plan

  variables {
    backup = { window = "3am-4am" }
  }

  expect_failures = [var.backup]
}

run "instance_is_encrypted_with_managed_password_and_iam_auth" {
  command = plan

  assert {
    condition = (
      aws_db_instance.this.engine == "postgres" &&
      aws_db_instance.this.storage_encrypted == true &&
      aws_db_instance.this.kms_key_id == var.kms_key_arn &&
      aws_db_instance.this.manage_master_user_password == true &&
      aws_db_instance.this.master_user_secret_kms_key_id == var.kms_key_arn &&
      aws_db_instance.this.iam_database_authentication_enabled == true &&
      aws_db_instance.this.publicly_accessible == false
    )
    error_message = "La instancia debe cifrarse con la CMK, gestionar la contraseña maestra en Secrets Manager, permitir IAM y no ser pública."
  }

  assert {
    condition     = aws_db_instance.this.password == null && aws_db_instance.this.password_wo == null
    error_message = "Ninguna contraseña maestra puede pasar por el código."
  }
}

run "instance_uses_gp3_graviton_insights_and_final_snapshot" {
  command = plan

  assert {
    condition = (
      aws_db_instance.this.storage_type == "gp3" &&
      aws_db_instance.this.allocated_storage == 20 &&
      aws_db_instance.this.max_allocated_storage == 100 &&
      aws_db_instance.this.instance_class == "db.t4g.medium" &&
      aws_db_instance.this.performance_insights_enabled == true &&
      aws_db_instance.this.performance_insights_kms_key_id == var.kms_key_arn &&
      aws_db_instance.this.performance_insights_retention_period == 7 &&
      aws_db_instance.this.database_insights_mode == "standard"
    )
    error_message = "gp3 con autoescalado, clase Graviton y Database Insights standard con CMK."
  }

  assert {
    condition = (
      toset(aws_db_subnet_group.this.subnet_ids) == toset(var.subnet_ids) &&
      toset(aws_db_instance.this.enabled_cloudwatch_logs_exports) == toset(["postgresql"]) &&
      aws_db_instance.this.copy_tags_to_snapshot == true &&
      aws_db_instance.this.skip_final_snapshot == false &&
      aws_db_instance.this.final_snapshot_identifier == "acme-dev-postgres-final" &&
      aws_db_instance.this.allow_major_version_upgrade == false
    )
    error_message = "Subnet group de data, logs exportados, tags a snapshots, instantánea final y sin saltos de versión mayor."
  }
}

run "advanced_database_insights_needs_long_retention" {
  command = plan

  variables {
    database_insights_mode = "advanced"
  }

  assert {
    condition     = aws_db_instance.this.database_insights_mode == "advanced" && aws_db_instance.this.performance_insights_retention_period == 465
    error_message = "Database Insights advanced exige 465 días de retención."
  }
}

run "dev_defaults_are_relaxed_but_safe" {
  command = plan

  assert {
    condition = (
      aws_db_instance.this.multi_az == false &&
      aws_db_instance.this.backup_retention_period == 7 &&
      aws_db_instance.this.deletion_protection == false
    )
    error_message = "dev: sin Multi-AZ, 7 días de backup y sin protección de borrado."
  }
}

run "prod_defaults_are_strict" {
  command = plan

  variables {
    environment = "prod"
    app_secret_rotation = {
      subnet_ids                 = ["subnet-0cccccccccccccccc", "subnet-0dddddddddddddddd"]
      endpoint_security_group_id = "sg-0eeeeeeeeeeeeeeee"
    }
  }

  assert {
    condition = (
      aws_db_instance.this.multi_az == true &&
      aws_db_instance.this.backup_retention_period == 35 &&
      aws_db_instance.this.deletion_protection == true &&
      aws_db_instance.this.skip_final_snapshot == false &&
      aws_db_instance.this.monitoring_interval == 60
    )
    error_message = "prod: Multi-AZ, 35 días de backup, protección de borrado, instantánea final y Enhanced Monitoring."
  }
}

run "single_az_can_pin_availability_zone" {
  command = plan

  variables {
    availability_zone = "us-east-1b"
  }

  assert {
    condition     = aws_db_instance.this.availability_zone == "us-east-1b"
    error_message = "En Single-AZ la AZ indicada debe respetarse."
  }
}

run "storage_autoscaling_can_be_disabled" {
  command = plan

  variables {
    storage = { allocated_gb = 50, max_allocated_gb = 0 }
  }

  assert {
    condition     = aws_db_instance.this.max_allocated_storage == null && aws_db_instance.this.allocated_storage == 50
    error_message = "max_allocated_gb = 0 debe desactivar el autoescalado."
  }
}

run "custom_port_applies_to_instance_and_rules" {
  command = plan

  variables {
    port = 15432
  }

  assert {
    condition = (
      aws_db_instance.this.port == 15432 &&
      alltrue([for r in aws_vpc_security_group_ingress_rule.from_allowed : r.from_port == 15432])
    )
    error_message = "El puerto debe propagarse a la instancia y a las reglas."
  }
}

run "backup_plan_tag_is_set_when_requested" {
  command = plan

  variables {
    backup_plan = "growth"
  }

  assert {
    condition     = aws_db_instance.this.tags["BackupPlan"] == "growth"
    error_message = "La instancia debe llevar la etiqueta BackupPlan para entrar en AWS Backup."
  }
}

run "no_backup_plan_tag_by_default" {
  command = plan

  assert {
    condition     = !contains(keys(aws_db_instance.this.tags), "BackupPlan")
    error_message = "Sin backup_plan no debe haber etiqueta BackupPlan."
  }
}

run "ssm_parameters_are_published_under_data_layer" {
  command = apply

  assert {
    condition = toset(keys(aws_ssm_parameter.this)) == toset([
      "endpoint", "port", "database_name", "instance_arn", "app_secret_arn", "master_secret_arn",
    ])
    error_message = "Deben publicarse endpoint, puerto, base, ARN de la instancia y de los secretos."
  }

  assert {
    condition = (
      aws_ssm_parameter.this["endpoint"].name == "/acme/dev/data/postgres/endpoint" &&
      alltrue([for p in aws_ssm_parameter.this : p.type == "String"])
    )
    error_message = "Los parámetros viven en /<project>/<env>/data/<namespace>/<clave> y no son SecureString (no hay secretos)."
  }
}

run "iam_auth_arn_prefix_uses_resource_id" {
  command = apply

  assert {
    condition     = output.iam_auth_resource_arn_prefix == "arn:aws:rds-db:us-east-1:123456789012:dbuser:db-ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    error_message = "El prefijo rds-db:connect debe construirse con el ID de recurso de la instancia."
  }
}

run "rejects_prod_without_multi_az" {
  command = plan

  variables {
    app_secret_rotation = {
      subnet_ids                 = ["subnet-0cccccccccccccccc", "subnet-0dddddddddddddddd"]
      endpoint_security_group_id = "sg-0eeeeeeeeeeeeeeee"
    }
    environment = "prod"
    multi_az    = false
  }

  expect_failures = [var.multi_az]
}

run "rejects_max_storage_below_allocated" {
  command = plan

  variables {
    storage = { allocated_gb = 100, max_allocated_gb = 50 }
  }

  expect_failures = [var.storage]
}

run "rejects_storage_below_gp3_minimum" {
  command = plan

  variables {
    storage = { allocated_gb = 10 }
  }

  expect_failures = [var.storage]
}

run "app_secret_recovery_window_passes_through" {
  command = apply

  variables {
    app_secret_recovery_window_in_days = 0
  }

  assert {
    condition     = output.app_secret_arn != output.master_user_secret_arn
    error_message = "Con borrado inmediato (dev) el secreto de la aplicación se sigue creando aparte del maestro."
  }
}
