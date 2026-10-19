# Pruebas unitarias de la capa (mock_provider, sin coste): composición, cableado entre capas por SSM
# y valores por entorno. La lógica de cada módulo la prueban sus propios tests.

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws", dns_suffix = "amazonaws.com" }
  }
  mock_data "aws_region" {
    defaults = { region = "us-east-1" }
  }
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
  mock_resource "aws_kms_key" {
    defaults = { arn = "arn:aws:kms:us-east-1:123456789012:key/11111111-2222-3333-4444-555555555555" }
  }
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::123456789012:role/acme-dev-mock" }
  }
  mock_resource "aws_cloudwatch_log_group" {
    defaults = { arn = "arn:aws:logs:us-east-1:123456789012:log-group:/mock" }
  }
  mock_resource "aws_sns_topic" {
    defaults = { arn = "arn:aws:sns:us-east-1:123456789012:acme-dev-alarms" }
  }
  mock_resource "aws_s3_bucket" {
    defaults = { arn = "arn:aws:s3:::acme-dev-mock-123456789012", id = "acme-dev-mock-123456789012" }
  }
  mock_resource "aws_acm_certificate" {
    defaults = {
      arn = "arn:aws:acm:us-east-1:123456789012:certificate/11111111-2222-3333-4444-555555555555"
      domain_validation_options = [{
        domain_name           = "shop.example.com"
        resource_record_name  = "_abc.shop.example.com."
        resource_record_type  = "CNAME"
        resource_record_value = "_xyz.acm-validations.aws."
      }]
    }
  }
  mock_data "aws_elb_service_account" {
    defaults = { arn = "arn:aws:iam::127311923021:root" }
  }
  mock_resource "aws_security_group" {
    defaults = { id = "sg-0123456789abcdef0" }
  }
  mock_resource "aws_vpc" {
    defaults = { id = "vpc-0123456789abcdef0" }
  }
  mock_resource "aws_subnet" {
    defaults = { id = "subnet-0123456789abcdef0" }
  }
  mock_resource "aws_vpc_endpoint" {
    defaults = { prefix_list_id = "pl-63a5400a" }
  }
  mock_resource "aws_lambda_function" {
    defaults = {
      arn        = "arn:aws:lambda:us-east-1:123456789012:function:acme-dev-api"
      invoke_arn = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:123456789012:function:acme-dev-api/invocations"
    }
  }
  mock_resource "aws_apigatewayv2_api" {
    defaults = {
      id            = "a1b2c3d4e5"
      api_endpoint  = "https://a1b2c3d4e5.execute-api.us-east-1.amazonaws.com"
      execution_arn = "arn:aws:execute-api:us-east-1:123456789012:a1b2c3d4e5"
    }
  }
  mock_resource "aws_api_gateway_rest_api" {
    defaults = {
      id               = "r1s2t3u4v5"
      root_resource_id = "abcdef1234"
      execution_arn    = "arn:aws:execute-api:us-east-1:123456789012:r1s2t3u4v5"
    }
  }
  mock_resource "aws_api_gateway_stage" {
    defaults = {
      arn        = "arn:aws:apigateway:us-east-1::/restapis/r1s2t3u4v5/stages/v1"
      invoke_url = "https://r1s2t3u4v5.execute-api.us-east-1.amazonaws.com/v1"
    }
  }
  mock_resource "aws_cognito_user_pool" {
    defaults = {
      id       = "us-east-1_EXAMPLE1"
      arn      = "arn:aws:cognito-idp:us-east-1:123456789012:userpool/us-east-1_EXAMPLE1"
      endpoint = "cognito-idp.us-east-1.amazonaws.com/us-east-1_EXAMPLE1"
    }
  }
  mock_resource "aws_cloudwatch_event_bus" {
    defaults = { arn = "arn:aws:events:us-east-1:123456789012:event-bus/acme-dev-events" }
  }
  mock_resource "aws_sqs_queue" {
    defaults = { arn = "arn:aws:sqs:us-east-1:123456789012:acme-dev-dlq" }
  }
  mock_resource "aws_kinesis_firehose_delivery_stream" {
    defaults = { arn = "arn:aws:firehose:us-east-1:123456789012:deliverystream/acme-dev-events" }
  }
  mock_resource "aws_backup_vault" {
    defaults = { arn = "arn:aws:backup:us-east-1:123456789012:backup-vault:acme-dev-backup" }
  }
  mock_resource "aws_dynamodb_table" {
    defaults = { arn = "arn:aws:dynamodb:us-east-1:123456789012:table/acme-dev-table" }
  }
  mock_resource "aws_secretsmanager_secret" {
    defaults = { arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:acme-dev-secret-AbCdEf" }
  }
  mock_resource "aws_rds_cluster" {
    defaults = {
      arn                 = "arn:aws:rds:us-east-1:123456789012:cluster:acme-dev-aurora"
      cluster_resource_id = "cluster-ABCDEFGHIJKLMNOPQRSTUVWXYZ"
      master_user_secret = [{
        kms_key_id    = "arn:aws:kms:us-east-1:123456789012:key/11111111-2222-3333-4444-555555555555"
        secret_arn    = "arn:aws:secretsmanager:us-east-1:123456789012:secret:rds!cluster-abc-AbCdEf"
        secret_status = "active"
      }]
    }
  }
  mock_resource "aws_db_instance" {
    defaults = {
      arn         = "arn:aws:rds:us-east-1:123456789012:db:acme-dev-postgres"
      resource_id = "db-ABCDEFGHIJKLMNOPQRSTUVWXYZ"
      master_user_secret = [{
        kms_key_id    = "arn:aws:kms:us-east-1:123456789012:key/11111111-2222-3333-4444-555555555555"
        secret_arn    = "arn:aws:secretsmanager:us-east-1:123456789012:secret:rds!db-abc-AbCdEf"
        secret_status = "active"
      }]
    }
  }
  mock_resource "aws_cloudformation_stack" {
    defaults = {
      outputs = { RotationLambdaARN = "arn:aws:lambda:us-east-1:123456789012:function:acme-dev-rotation" }
    }
  }
  mock_resource "aws_elasticache_replication_group" {
    defaults = { arn = "arn:aws:elasticache:us-east-1:123456789012:replicationgroup:acme-dev-valkey" }
  }
  mock_resource "aws_elasticache_user" {
    defaults = { arn = "arn:aws:elasticache:us-east-1:123456789012:user:acme-dev-valkey-app" }
  }
  mock_resource "aws_lb" {
    defaults = {
      arn        = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/acme-dev/50dc6c495c0c9188"
      arn_suffix = "app/acme-dev/50dc6c495c0c9188"
      dns_name   = "internal-acme-dev-123456.us-east-1.elb.amazonaws.com"
    }
  }
  mock_resource "aws_lb_target_group" {
    defaults = {
      arn        = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/acme-dev-app/73e2d6bc24d8a067"
      arn_suffix = "targetgroup/acme-dev-app/73e2d6bc24d8a067"
    }
  }
  mock_resource "aws_lb_listener" {
    defaults = { arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/acme-dev/50dc6c495c0c9188/f2f7dc8efc522ab2" }
  }
  mock_resource "aws_ecs_cluster" {
    defaults = { arn = "arn:aws:ecs:us-east-1:123456789012:cluster/acme-dev" }
  }
  mock_resource "aws_ecr_repository" {
    defaults = {
      arn            = "arn:aws:ecr:us-east-1:123456789012:repository/acme-dev-app"
      repository_url = "123456789012.dkr.ecr.us-east-1.amazonaws.com/acme-dev-app"
    }
  }
  mock_resource "aws_wafv2_web_acl" {
    defaults = { arn = "arn:aws:wafv2:us-east-1:123456789012:regional/webacl/acme-dev/abcd" }
  }
  mock_resource "aws_organizations_account" {
    defaults = { id = "210987654321", arn = "arn:aws:organizations::123456789012:account/o-abcdefghij/210987654321" }
  }
  mock_resource "aws_organizations_organizational_unit" {
    defaults = { id = "ou-abcd-12345678", arn = "arn:aws:organizations::123456789012:ou/o-abcdefghij/ou-abcd-12345678" }
  }
}

override_data {
  target = data.aws_ssm_parameters_by_path.network
  values = {
    names  = ["/acme/dev/network/vpc_id", "/acme/dev/network/vpc_cidr", "/acme/dev/network/subnet_ids/public", "/acme/dev/network/subnet_ids/app", "/acme/dev/network/subnet_ids/data", "/acme/dev/network/route_table_ids/app", "/acme/dev/network/route_table_ids/data", "/acme/dev/network/kms_key_arn", "/acme/dev/network/logs_bucket_name", "/acme/dev/network/logs_bucket_arn", "/acme/dev/network/endpoints_security_group_id", "/acme/dev/network/s3_prefix_list_id", "/acme/dev/network/alarm_topic_arn", "/acme/dev/network/az_names"]
    values = ["vpc-0123456789abcdef0", "10.20.0.0/16", "subnet-0aaaaaaaaaaaaaaa1,subnet-0aaaaaaaaaaaaaaa2", "subnet-0bbbbbbbbbbbbbbb1,subnet-0bbbbbbbbbbbbbbb2", "subnet-0ccccccccccccccc1,subnet-0ccccccccccccccc2", "rtb-0bbbbbbbbbbbbbbb1,rtb-0bbbbbbbbbbbbbbb2", "rtb-0ccccccccccccccc1,rtb-0ccccccccccccccc2", "arn:aws:kms:us-east-1:123456789012:key/11111111-2222-3333-4444-555555555555", "acme-dev-logs-123456789012", "arn:aws:s3:::acme-dev-logs-123456789012", "sg-0eeeeeeeeeeeeeee1", "pl-63a5400a", "arn:aws:sns:us-east-1:123456789012:acme-dev-alarms", "us-east-1a,us-east-1b"]
  }
}

override_data {
  target = data.aws_ssm_parameters_by_path.data
  values = {
    names  = ["/acme/dev/data/kms_key_arn", "/acme/dev/data/aurora/writer_endpoint", "/acme/dev/data/aurora/reader_endpoint", "/acme/dev/data/aurora/port", "/acme/dev/data/aurora/database_name", "/acme/dev/data/aurora/cluster_arn", "/acme/dev/data/aurora/app_secret_arn", "/acme/dev/data/aurora/master_secret_arn", "/acme/dev/data/aurora/security_group_id", "/acme/dev/data/aurora/cluster_id", "/acme/dev/data/aurora/instance_count", "/acme/dev/data/valkey/primary_endpoint", "/acme/dev/data/valkey/reader_endpoint", "/acme/dev/data/valkey/port", "/acme/dev/data/valkey/replication_group_id", "/acme/dev/data/valkey/replication_group_arn", "/acme/dev/data/valkey/security_group_id", "/acme/dev/data/valkey/iam_user_arn", "/acme/dev/data/valkey/iam_user_name", "/acme/dev/data/valkey/node_count"]
    values = ["arn:aws:kms:us-east-1:123456789012:key/33333333-2222-3333-4444-555555555555", "acme-dev-aurora.cluster-abc.us-east-1.rds.amazonaws.com", "acme-dev-aurora.cluster-ro-abc.us-east-1.rds.amazonaws.com", "5432", "app", "arn:aws:rds:us-east-1:123456789012:cluster:acme-dev-aurora", "arn:aws:secretsmanager:us-east-1:123456789012:secret:acme-dev-aurora-app-AbCdEf", "arn:aws:secretsmanager:us-east-1:123456789012:secret:rds!cluster-abc-AbCdEf", "sg-0ddddddddddddddd1", "acme-dev-aurora", "1", "master.acme-dev-valkey.abc.use1.cache.amazonaws.com", "replica.acme-dev-valkey.abc.use1.cache.amazonaws.com", "6379", "acme-dev-valkey", "arn:aws:elasticache:us-east-1:123456789012:replicationgroup:acme-dev-valkey", "sg-0fffffffffffffff1", "arn:aws:elasticache:us-east-1:123456789012:user:acme-dev-valkey-app", "acme-dev-valkey-app", "1"]
  }
}

variables {
  project     = "acme"
  environment = "dev"
  domain_name = "shop.example.com"
  zone_id     = "Z0123456789ABCDEFGHIJ"

  service = {
    image      = "123456789012.dkr.ecr.us-east-1.amazonaws.com/acme-dev-app@sha256:0000000000000000000000000000000000000000000000000000000000000000"
    otel_image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/aws-otel-collector@sha256:1111111111111111111111111111111111111111111111111111111111111111"
  }
}


run "app_layer_wiring_with_cache_and_otel" {
  command = plan

  variables {
    allow_internet_egress = true
  }

  assert {
    condition     = toset(keys(local.egress_rules)) == toset(["endpoints", "s3", "postgres", "valkey", "internet"]) && local.egress_rules["valkey"].port == 6379
    error_message = "Las tareas salen a endpoints, S3, Aurora, Valkey y HTTPS por la NAT."
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.cache_from_service) == 1 && aws_vpc_security_group_ingress_rule.cache_from_service[0].security_group_id == "sg-0fffffffffffffff1"
    error_message = "La capa app abre el SG de Valkey a las tareas (ADR 0016)."
  }

  assert {
    condition     = toset(keys(local.task_role_policies)) == toset(["events", "valkey"])
    error_message = "El task role publica eventos y se autentica en Valkey por IAM; nada más."
  }

  assert {
    condition     = local.otel_enabled && local.app_environment["OTEL_EXPORTER_OTLP_ENDPOINT"] == "http://localhost:4318" && local.app_environment["CACHE_USER"] == "acme-dev-valkey-app"
    error_message = "Con otel_image el servicio lleva el sidecar ADOT y la app recibe la configuración OTLP y de Valkey."
  }
}

run "without_cache" {
  command = plan

  override_data {
    target = data.aws_ssm_parameters_by_path.data
    values = {
      names  = ["/acme/dev/data/kms_key_arn", "/acme/dev/data/aurora/writer_endpoint", "/acme/dev/data/aurora/reader_endpoint", "/acme/dev/data/aurora/port", "/acme/dev/data/aurora/database_name", "/acme/dev/data/aurora/cluster_arn", "/acme/dev/data/aurora/app_secret_arn", "/acme/dev/data/aurora/master_secret_arn", "/acme/dev/data/aurora/security_group_id", "/acme/dev/data/aurora/cluster_id", "/acme/dev/data/aurora/instance_count"]
      values = ["arn:aws:kms:us-east-1:123456789012:key/33333333-2222-3333-4444-555555555555", "acme-dev-aurora.cluster-abc.us-east-1.rds.amazonaws.com", "acme-dev-aurora.cluster-ro-abc.us-east-1.rds.amazonaws.com", "5432", "app", "arn:aws:rds:us-east-1:123456789012:cluster:acme-dev-aurora", "arn:aws:secretsmanager:us-east-1:123456789012:secret:acme-dev-aurora-app-AbCdEf", "arn:aws:secretsmanager:us-east-1:123456789012:secret:rds!cluster-abc-AbCdEf", "sg-0ddddddddddddddd1", "acme-dev-aurora", "1"]
    }
  }

  assert {
    condition     = !local.cache_enabled && !contains(keys(local.egress_rules), "valkey") && length(aws_vpc_security_group_ingress_rule.cache_from_service) == 0 && !contains(keys(local.task_role_policies), "valkey")
    error_message = "Sin Valkey en la capa data, la app no abre ni pide acceso a la caché."
  }
}
