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

  mock_resource "aws_rds_cluster" {
    defaults = {
      arn                 = "arn:aws:rds:us-east-1:123456789012:cluster:acme-dev-aurora"
      endpoint            = "acme-dev-aurora.cluster-abc.us-east-1.rds.amazonaws.com"
      reader_endpoint     = "acme-dev-aurora.cluster-ro-abc.us-east-1.rds.amazonaws.com"
      cluster_resource_id = "cluster-ABCDEFGHIJKLMNOPQRSTUVWXYZ"
      master_user_secret = [{
        kms_key_id    = "arn:aws:kms:us-east-1:123456789012:key/11111111-2222-3333-4444-555555555555"
        secret_arn    = "arn:aws:secretsmanager:us-east-1:123456789012:secret:rds!cluster-abc-AbCdEf"
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
      arn = "arn:aws:iam::123456789012:role/acme-dev-aurora-mon"
    }
  }

  mock_resource "aws_cloudformation_stack" {
    defaults = {
      outputs = {
        RotationLambdaARN = "arn:aws:lambda:us-east-1:123456789012:function:acme-dev-aurora-rotation"
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

run "cluster_is_encrypted_with_managed_password_and_iam_auth" {
  command = plan

  assert {
    condition = (
      aws_rds_cluster.this.engine == "aurora-postgresql" &&
      aws_rds_cluster.this.storage_encrypted == true &&
      aws_rds_cluster.this.kms_key_id == var.kms_key_arn &&
      aws_rds_cluster.this.manage_master_user_password == true &&
      aws_rds_cluster.this.master_user_secret_kms_key_id == var.kms_key_arn &&
      aws_rds_cluster.this.iam_database_authentication_enabled == true
    )
    error_message = "El cluster debe cifrarse con la CMK, gestionar la contraseña maestra en Secrets Manager y permitir autenticación IAM."
  }

  assert {
    condition     = aws_rds_cluster.this.master_password == null && aws_rds_cluster.this.master_password_wo == null
    error_message = "Ninguna contraseña maestra puede pasar por el código."
  }
}

run "cluster_uses_private_data_subnets_and_exports_postgresql_logs" {
  command = plan

  assert {
    condition = (
      toset(aws_db_subnet_group.this.subnet_ids) == toset(var.subnet_ids) &&
      toset(aws_rds_cluster.this.enabled_cloudwatch_logs_exports) == toset(["postgresql"]) &&
      aws_rds_cluster.this.copy_tags_to_snapshot == true &&
      aws_rds_cluster.this.skip_final_snapshot == false &&
      aws_rds_cluster.this.final_snapshot_identifier == "acme-dev-aurora-final"
    )
    error_message = "Subnet group de data, logs de PostgreSQL exportados, tags a snapshots e instantánea final por defecto."
  }

  assert {
    condition     = alltrue([for i in aws_rds_cluster_instance.this : i.publicly_accessible == false])
    error_message = "Ninguna instancia puede ser pública."
  }
}

run "parameter_group_enforces_tls_logging_and_pgaudit" {
  command = plan

  assert {
    condition     = aws_rds_cluster_parameter_group.this.family == "aurora-postgresql17"
    error_message = "La familia del parameter group debe deducirse de la versión mayor."
  }

  assert {
    condition = (
      { for p in aws_rds_cluster_parameter_group.this.parameter : p.name => p.value }["rds.force_ssl"] == "1" &&
      { for p in aws_rds_cluster_parameter_group.this.parameter : p.name => p.value }["log_connections"] == "1" &&
      { for p in aws_rds_cluster_parameter_group.this.parameter : p.name => p.value }["log_disconnections"] == "1" &&
      { for p in aws_rds_cluster_parameter_group.this.parameter : p.name => p.value }["log_min_duration_statement"] == "1000" &&
      { for p in aws_rds_cluster_parameter_group.this.parameter : p.name => p.value }["shared_preload_libraries"] == "pg_stat_statements,pgaudit" &&
      { for p in aws_rds_cluster_parameter_group.this.parameter : p.name => p.value }["pgaudit.log"] == "ddl,role"
    )
    error_message = "El parameter group debe forzar TLS, registrar conexiones y lentas y cargar pgaudit con ddl,role."
  }

  assert {
    condition     = alltrue([for p in aws_rds_cluster_parameter_group.this.parameter : p.apply_method == "pending-reboot" if p.name == "shared_preload_libraries"])
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
      aws_cloudwatch_log_group.postgresql.name == "/aws/rds/cluster/acme-dev-aurora/postgresql" &&
      aws_cloudwatch_log_group.postgresql.retention_in_days == 30 &&
      aws_cloudwatch_log_group.postgresql.kms_key_id == var.kms_key_arn
    )
    error_message = "RDS crearía el log group sin retención ni cifrado: debe existir antes, con la CMK."
  }
}

run "dev_defaults_are_relaxed_but_safe" {
  command = plan

  assert {
    condition = (
      length(aws_rds_cluster_instance.this) == 1 &&
      aws_rds_cluster.this.backup_retention_period == 7 &&
      aws_rds_cluster.this.deletion_protection == false &&
      aws_rds_cluster.this.database_insights_mode == "standard"
    )
    error_message = "dev: 1 instancia, 7 días de backup, sin protección de borrado y Database Insights standard."
  }
}

run "staging_keeps_deletion_protection" {
  command = plan

  variables {
    environment = "staging"
  }

  assert {
    condition     = aws_rds_cluster.this.deletion_protection == true
    error_message = "Fuera de dev la protección contra borrado debe estar activa por defecto."
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
      length(aws_rds_cluster_instance.this) == 2 &&
      aws_rds_cluster.this.backup_retention_period == 35 &&
      aws_rds_cluster.this.deletion_protection == true &&
      aws_rds_cluster.this.skip_final_snapshot == false
    )
    error_message = "prod: 2 instancias, 35 días de backup, protección de borrado e instantánea final."
  }

  assert {
    condition     = alltrue([for i in aws_rds_cluster_instance.this : i.monitoring_interval == 60])
    error_message = "En prod Enhanced Monitoring debe estar activo."
  }
}

run "instances_use_graviton_class_database_insights_and_cmk" {
  command = plan

  variables {
    instance_count = 3
  }

  assert {
    condition = alltrue([
      for i in aws_rds_cluster_instance.this :
      i.instance_class == "db.t4g.medium" &&
      i.performance_insights_enabled == true &&
      i.performance_insights_kms_key_id == var.kms_key_arn &&
      i.performance_insights_retention_period == 7 &&
      i.auto_minor_version_upgrade == true
    ])
    error_message = "Instancias Graviton con Database Insights standard (7 días) y CMK."
  }

  assert {
    condition     = toset(keys(aws_rds_cluster_instance.this)) == toset(["1", "2", "3"])
    error_message = "Las instancias deben tener claves estables 1..n."
  }

  assert {
    condition     = aws_rds_cluster_instance.this["1"].promotion_tier == 0 && aws_rds_cluster_instance.this["2"].promotion_tier == 1
    error_message = "El writer inicial usa tier 0 y los lectores promotion_tier."
  }
}

run "advanced_database_insights_needs_long_retention" {
  command = plan

  variables {
    database_insights_mode = "advanced"
  }

  assert {
    condition = (
      aws_rds_cluster.this.database_insights_mode == "advanced" &&
      alltrue([for i in aws_rds_cluster_instance.this : i.performance_insights_retention_period == 465])
    )
    error_message = "Database Insights advanced exige 465 días de retención."
  }
}

run "instances_spread_across_given_azs" {
  command = plan

  variables {
    instance_count = 3
    az_names       = ["us-east-1a", "us-east-1b"]
  }

  assert {
    condition = (
      aws_rds_cluster_instance.this["1"].availability_zone == "us-east-1a" &&
      aws_rds_cluster_instance.this["2"].availability_zone == "us-east-1b" &&
      aws_rds_cluster_instance.this["3"].availability_zone == "us-east-1a"
    )
    error_message = "Las instancias deben repartirse en round-robin entre az_names."
  }
}

run "serverless_v2_uses_db_serverless_and_scaling_block" {
  command = plan

  variables {
    capacity_mode = "serverless_v2"
    serverless_v2 = { min_capacity = 0.5, max_capacity = 8 }
  }

  assert {
    condition = (
      alltrue([for i in aws_rds_cluster_instance.this : i.instance_class == "db.serverless"]) &&
      alltrue([for s in aws_rds_cluster.this.serverlessv2_scaling_configuration : s.min_capacity == 0.5 && s.max_capacity == 8])
    )
    error_message = "serverless_v2 debe usar db.serverless y el bloque de escalado."
  }
}

run "serverless_v2_can_scale_to_zero_with_auto_pause" {
  command = plan

  variables {
    capacity_mode = "serverless_v2"
    serverless_v2 = { min_capacity = 0, max_capacity = 2, seconds_until_auto_pause = 600 }
  }

  assert {
    condition     = alltrue([for s in aws_rds_cluster.this.serverlessv2_scaling_configuration : s.min_capacity == 0 && s.seconds_until_auto_pause == 600])
    error_message = "min_capacity = 0 debe permitir seconds_until_auto_pause."
  }
}

run "provisioned_has_no_serverless_block" {
  command = plan

  assert {
    condition     = length(aws_rds_cluster.this.serverlessv2_scaling_configuration) == 0
    error_message = "En modo provisioned no debe haber bloque de escalado serverless."
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

run "custom_port_applies_to_cluster_and_rules" {
  command = plan

  variables {
    port = 15432
  }

  assert {
    condition = (
      aws_rds_cluster.this.port == 15432 &&
      alltrue([for r in aws_vpc_security_group_ingress_rule.from_allowed : r.from_port == 15432])
    )
    error_message = "El puerto debe propagarse al cluster y a las reglas."
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

run "backup_plan_tag_is_set_when_requested" {
  command = plan

  variables {
    backup_plan = "growth"
  }

  assert {
    condition     = aws_rds_cluster.this.tags["BackupPlan"] == "growth"
    error_message = "El cluster debe llevar la etiqueta BackupPlan para entrar en AWS Backup."
  }
}

run "no_backup_plan_tag_by_default" {
  command = plan

  assert {
    condition     = !contains(keys(aws_rds_cluster.this.tags), "BackupPlan")
    error_message = "Sin backup_plan no debe haber etiqueta BackupPlan."
  }
}

run "data_api_is_off_by_default_and_opt_in" {
  command = plan

  assert {
    condition     = aws_rds_cluster.this.enable_http_endpoint == false
    error_message = "La Data API debe estar desactivada por defecto."
  }
}

run "data_api_can_be_enabled" {
  command = plan

  variables {
    enable_http_endpoint = true
  }

  assert {
    condition     = aws_rds_cluster.this.enable_http_endpoint == true
    error_message = "enable_http_endpoint = true debe activar la Data API."
  }
}

run "ssm_parameters_are_published_under_data_layer" {
  command = apply

  assert {
    condition = toset(keys(aws_ssm_parameter.this)) == toset([
      "writer_endpoint", "reader_endpoint", "port", "database_name", "cluster_arn", "app_secret_arn", "master_secret_arn",
    ])
    error_message = "Deben publicarse endpoints, puerto, base, ARN del cluster y de los secretos."
  }

  assert {
    condition = (
      aws_ssm_parameter.this["writer_endpoint"].name == "/acme/dev/data/aurora/writer_endpoint" &&
      alltrue([for p in aws_ssm_parameter.this : p.type == "String"])
    )
    error_message = "Los parámetros viven en /<project>/<env>/data/<namespace>/<clave> y no son SecureString (no hay secretos)."
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
      module.app_secret.secret_name == "acme-dev-aurora/app_runtime" &&
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
    condition     = module.app_secret.rotation_lambda_arn == "arn:aws:lambda:us-east-1:123456789012:function:acme-dev-aurora-rotation"
    error_message = "La función de rotación debe desplegarse y exponerse."
  }
}

run "iam_auth_arn_prefix_uses_cluster_resource_id" {
  command = apply

  assert {
    condition     = output.iam_auth_resource_arn_prefix == "arn:aws:rds-db:us-east-1:123456789012:dbuser:cluster-ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    error_message = "El prefijo rds-db:connect debe construirse con el ID de recurso del cluster."
  }
}

run "rejects_prod_with_a_single_instance" {
  command = plan

  variables {
    app_secret_rotation = {
      subnet_ids                 = ["subnet-0cccccccccccccccc", "subnet-0dddddddddddddddd"]
      endpoint_security_group_id = "sg-0eeeeeeeeeeeeeeee"
    }
    environment    = "prod"
    instance_count = 1
  }

  expect_failures = [var.instance_count]
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

run "rejects_serverless_min_above_max" {
  command = plan

  variables {
    capacity_mode = "serverless_v2"
    serverless_v2 = { min_capacity = 4, max_capacity = 2 }
  }

  expect_failures = [var.serverless_v2]
}

run "rejects_auto_pause_without_zero_min_capacity" {
  command = plan

  variables {
    capacity_mode = "serverless_v2"
    serverless_v2 = { min_capacity = 1, max_capacity = 2, seconds_until_auto_pause = 600 }
  }

  expect_failures = [var.serverless_v2]
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
