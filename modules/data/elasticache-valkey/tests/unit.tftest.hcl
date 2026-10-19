mock_provider "aws" {
  mock_resource "aws_elasticache_replication_group" {
    defaults = {
      arn                      = "arn:aws:elasticache:us-east-1:123456789012:replicationgroup:acme-dev-valkey"
      primary_endpoint_address = "master.acme-dev-valkey.abc.use1.cache.amazonaws.com"
      reader_endpoint_address  = "replica.acme-dev-valkey.abc.use1.cache.amazonaws.com"
    }
  }

  mock_resource "aws_elasticache_user" {
    defaults = {
      arn = "arn:aws:elasticache:us-east-1:123456789012:user:acme-dev-valkey-app"
    }
  }

  mock_resource "aws_security_group" {
    defaults = {
      id = "sg-0123456789abcdef0"
    }
  }
}

variables {
  project     = "acme"
  environment = "dev"
  vpc_id      = "vpc-0123456789abcdef0"
  subnet_ids  = ["subnet-0aaaaaaaaaaaaaaaa", "subnet-0bbbbbbbbbbbbbbbb"]
  kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/11111111-2222-3333-4444-555555555555"

  allowed_security_group_ids = {
    app    = "sg-0aaaaaaaaaaaaaaaa"
    worker = "sg-0bbbbbbbbbbbbbbbb"
  }
}

run "replication_group_is_valkey_encrypted_in_transit_and_at_rest" {
  command = plan

  assert {
    condition = (
      aws_elasticache_replication_group.this.engine == "valkey" &&
      aws_elasticache_replication_group.this.transit_encryption_enabled == true &&
      aws_elasticache_replication_group.this.transit_encryption_mode == "required" &&
      aws_elasticache_replication_group.this.at_rest_encryption_enabled == "true" &&
      aws_elasticache_replication_group.this.kms_key_id == var.kms_key_arn
    )
    error_message = "Valkey debe cifrar en tránsito (modo required) y en reposo con la CMK."
  }

  assert {
    condition     = aws_elasticache_replication_group.this.auth_token == null && aws_elasticache_replication_group.this.auth_token_wo == null
    error_message = "No debe haber AUTH token: la autenticación es IAM."
  }
}

run "defaults_have_only_iam_users" {
  command = plan

  assert {
    condition     = toset(keys(aws_elasticache_user.app)) == toset(["app"])
    error_message = "Por defecto existe solo el usuario de aplicación (sin usuario default)."
  }

  assert {
    condition = alltrue([
      for u in aws_elasticache_user.app :
      u.user_id == u.user_name && alltrue([for m in u.authentication_mode : m.type == "iam"]) && u.engine == "valkey"
    ])
    error_message = "Los usuarios de aplicación usan autenticación IAM con user_id == user_name."
  }

  assert {
    condition     = toset(aws_elasticache_user_group.this.user_ids) == toset(["acme-dev-valkey-app"])
    error_message = "El grupo contiene solo los usuarios IAM (sin default: ninguna conexión sin autenticar)."
  }
}

run "no_user_has_a_password" {
  command = plan

  assert {
    condition     = alltrue([for u in aws_elasticache_user.app : u.passwords == null && u.no_password_required != true])
    error_message = "Ningún usuario puede tener contraseña en el código."
  }
}

run "multiple_iam_users_get_stable_ids_and_acls" {
  command = plan

  variables {
    iam_users = {
      app    = {}
      report = { access_string = "on ~* +@read -@dangerous" }
    }
  }

  assert {
    condition = (
      aws_elasticache_user.app["report"].user_id == "acme-dev-valkey-report" &&
      aws_elasticache_user.app["report"].access_string == "on ~* +@read -@dangerous" &&
      aws_elasticache_user.app["app"].access_string == "on ~* +@all -@dangerous"
    )
    error_message = "Cada usuario debe llevar su ACL y un user_id estable <name>-<clave>."
  }
}

run "single_node_has_no_failover_in_dev" {
  command = plan

  assert {
    condition = (
      aws_elasticache_replication_group.this.num_cache_clusters == 1 &&
      aws_elasticache_replication_group.this.automatic_failover_enabled == false &&
      aws_elasticache_replication_group.this.multi_az_enabled == false
    )
    error_message = "dev: un nodo, sin failover ni Multi-AZ."
  }
}

run "two_nodes_enable_failover_and_multi_az" {
  command = plan

  variables {
    num_cache_clusters = 2
  }

  assert {
    condition = (
      aws_elasticache_replication_group.this.automatic_failover_enabled == true &&
      aws_elasticache_replication_group.this.multi_az_enabled == true
    )
    error_message = "Con 2 o más nodos deben activarse failover automático y Multi-AZ."
  }
}

run "prod_defaults_to_two_nodes_and_strict_retention" {
  command = plan

  variables {
    environment = "prod"
  }

  assert {
    condition = (
      aws_elasticache_replication_group.this.num_cache_clusters == 2 &&
      aws_elasticache_replication_group.this.automatic_failover_enabled == true &&
      aws_elasticache_replication_group.this.final_snapshot_identifier == "acme-prod-valkey-final" &&
      aws_elasticache_replication_group.this.snapshot_retention_limit == 7
    )
    error_message = "prod: 2 nodos con failover, copia final y 7 días de snapshots."
  }
}

run "parameter_group_family_follows_major_version" {
  command = plan

  assert {
    condition = (
      aws_elasticache_parameter_group.this.family == "valkey8" &&
      { for p in aws_elasticache_parameter_group.this.parameter : p.name => p.value }["maxmemory-policy"] == "volatile-lru"
    )
    error_message = "La familia debe deducirse de la versión mayor y maxmemory-policy tomar su valor por defecto."
  }
}

run "valkey_7_2_uses_valkey7_family_and_custom_policy" {
  command = plan

  variables {
    engine_version   = "7.2"
    maxmemory_policy = "noeviction"
  }

  assert {
    condition = (
      aws_elasticache_parameter_group.this.family == "valkey7" &&
      { for p in aws_elasticache_parameter_group.this.parameter : p.name => p.value }["maxmemory-policy"] == "noeviction"
    )
    error_message = "Valkey 7.2 usa la familia valkey7 y la política indicada."
  }
}

run "snapshots_can_be_disabled_outside_prod" {
  command = plan

  variables {
    snapshots              = { retention_days = 0 }
    final_snapshot_enabled = false
  }

  assert {
    condition = (
      aws_elasticache_replication_group.this.snapshot_retention_limit == 0 &&
      aws_elasticache_replication_group.this.final_snapshot_identifier == null
    )
    error_message = "retention_days = 0 desactiva las copias y sin copia final no debe haber nombre de copia."
  }
}

run "slow_and_engine_logs_go_to_encrypted_log_groups" {
  command = plan

  variables {
    log_retention_days = 30
  }

  assert {
    condition = (
      toset(keys(aws_cloudwatch_log_group.this)) == toset(["slow", "engine"]) &&
      alltrue([for g in aws_cloudwatch_log_group.this : g.kms_key_id == var.kms_key_arn && g.retention_in_days == 30])
    )
    error_message = "slow-log y engine-log deben tener log group con la CMK y la retención indicada."
  }

  assert {
    condition = (
      aws_cloudwatch_log_group.this["slow"].name == "/aws/elasticache/acme-dev-valkey/slow-log" &&
      toset([for l in aws_elasticache_replication_group.this.log_delivery_configuration : l.log_type]) == toset(["slow-log", "engine-log"]) &&
      alltrue([for l in aws_elasticache_replication_group.this.log_delivery_configuration : l.destination_type == "cloudwatch-logs" && l.log_format == "json"])
    )
    error_message = "Los dos registros deben entregarse a CloudWatch Logs en JSON."
  }
}

run "security_group_admits_only_declared_groups_on_valkey_port" {
  command = plan

  assert {
    condition     = toset(keys(aws_vpc_security_group_ingress_rule.from_allowed)) == toset(["app", "worker"])
    error_message = "Debe haber una regla de entrada por cada SG autorizado."
  }

  assert {
    condition = alltrue([
      for r in aws_vpc_security_group_ingress_rule.from_allowed :
      r.from_port == 6379 && r.to_port == 6379 && r.ip_protocol == "tcp" && r.cidr_ipv4 == null && r.cidr_ipv6 == null
    ])
    error_message = "Las reglas de entrada deben ser TCP 6379 por referencia de SG, nunca por CIDR."
  }
}

run "custom_port_applies_to_group_and_rules" {
  command = plan

  variables {
    port = 6380
  }

  assert {
    condition = (
      aws_elasticache_replication_group.this.port == 6380 &&
      alltrue([for r in aws_vpc_security_group_ingress_rule.from_allowed : r.from_port == 6380])
    )
    error_message = "El puerto debe propagarse al replication group y a las reglas."
  }
}

run "connect_arns_list_group_and_user" {
  command = apply

  assert {
    condition = (
      output.iam_connect_resource_arns["app"][0] == "arn:aws:elasticache:us-east-1:123456789012:replicationgroup:acme-dev-valkey" &&
      output.iam_connect_resource_arns["app"][1] == "arn:aws:elasticache:us-east-1:123456789012:user:acme-dev-valkey-app" &&
      output.iam_user_names["app"] == "acme-dev-valkey-app"
    )
    error_message = "elasticache:Connect necesita el ARN del replication group y el del usuario."
  }
}

run "ssm_parameters_are_published_under_data_layer" {
  command = apply

  assert {
    condition = toset(keys(aws_ssm_parameter.this)) == toset([
      "primary_endpoint", "reader_endpoint", "port", "replication_group_id", "replication_group_arn",
    ])
    error_message = "Deben publicarse endpoints, puerto, ID y ARN."
  }

  assert {
    condition = (
      aws_ssm_parameter.this["primary_endpoint"].name == "/acme/dev/data/valkey/primary_endpoint" &&
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

run "rejects_prod_with_a_single_node" {
  command = plan

  variables {
    environment        = "prod"
    num_cache_clusters = 1
  }

  expect_failures = [var.num_cache_clusters]
}

run "rejects_prod_without_final_snapshot" {
  command = plan

  variables {
    environment            = "prod"
    final_snapshot_enabled = false
  }

  expect_failures = [var.final_snapshot_enabled]
}

run "rejects_prod_with_short_snapshot_retention" {
  command = plan

  variables {
    environment = "prod"
    snapshots   = { retention_days = 1 }
  }

  expect_failures = [var.snapshots]
}

run "rejects_prod_with_short_log_retention" {
  command = plan

  variables {
    environment        = "prod"
    log_retention_days = 30
  }

  expect_failures = [var.log_retention_days]
}

run "rejects_engine_version_below_7_2" {
  command = plan

  variables {
    engine_version = "7.0"
  }

  expect_failures = [var.engine_version]
}

run "rejects_invalid_maxmemory_policy" {
  command = plan

  variables {
    maxmemory_policy = "allkeys-fifo"
  }

  expect_failures = [var.maxmemory_policy]
}

run "rejects_empty_iam_users" {
  command = plan

  variables {
    iam_users = {}
  }

  expect_failures = [var.iam_users]
}

run "rejects_disabled_iam_user_acl" {
  command = plan

  variables {
    iam_users = { app = { access_string = "off +@all" } }
  }

  expect_failures = [var.iam_users]
}

run "rejects_too_long_name" {
  command = plan

  variables {
    name = "acme-production-valkey-cache"
  }

  expect_failures = [var.name]
}

run "rejects_default_name_that_is_too_long" {
  command = plan

  variables {
    project = "a-very-long-project"
  }

  expect_failures = [var.name]
}

run "rejects_single_subnet" {
  command = plan

  variables {
    subnet_ids = ["subnet-0aaaaaaaaaaaaaaaa"]
  }

  expect_failures = [var.subnet_ids]
}

run "rejects_alias_as_kms_key" {
  command = plan

  variables {
    kms_key_arn = "arn:aws:kms:us-east-1:123456789012:alias/acme"
  }

  expect_failures = [var.kms_key_arn]
}
