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
    names  = ["/acme/dev/network/vpc_id", "/acme/dev/network/vpc_cidr", "/acme/dev/network/subnet_ids/public", "/acme/dev/network/subnet_ids/app", "/acme/dev/network/subnet_ids/data", "/acme/dev/network/route_table_ids/app", "/acme/dev/network/route_table_ids/data", "/acme/dev/network/kms_key_arn", "/acme/dev/network/logs_bucket_name", "/acme/dev/network/logs_bucket_arn", "/acme/dev/network/endpoints_security_group_id", "/acme/dev/network/s3_prefix_list_id", "/acme/dev/network/alarm_topic_arn"]
    values = ["vpc-0123456789abcdef0", "10.20.0.0/16", "subnet-0aaaaaaaaaaaaaaa1,subnet-0aaaaaaaaaaaaaaa2", "subnet-0bbbbbbbbbbbbbbb1,subnet-0bbbbbbbbbbbbbbb2", "subnet-0ccccccccccccccc1,subnet-0ccccccccccccccc2", "rtb-0bbbbbbbbbbbbbbb1,rtb-0bbbbbbbbbbbbbbb2", "rtb-0ccccccccccccccc1,rtb-0ccccccccccccccc2", "arn:aws:kms:us-east-1:123456789012:key/11111111-2222-3333-4444-555555555555", "acme-dev-logs-123456789012", "arn:aws:s3:::acme-dev-logs-123456789012", "sg-0eeeeeeeeeeeeeee1", "pl-63a5400a", "arn:aws:sns:us-east-1:123456789012:acme-dev-alarms"]
  }
}

variables {
  project     = "acme"
  environment = "dev"
}

run "data_layer_reads_network_and_wires_rotation" {
  command = plan

  assert {
    condition     = local.vpc_id == "vpc-0123456789abcdef0" && length(local.data_subnet_ids) == 2 && local.data_subnet_ids[0] == "subnet-0ccccccccccccccc1"
    error_message = "La capa data debe leer la VPC y las subredes data de SSM."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.endpoints_from_rotation.security_group_id == "sg-0eeeeeeeeeeeeeee1" && aws_vpc_security_group_ingress_rule.endpoints_from_rotation.from_port == 443
    error_message = "La función de rotación necesita entrar al endpoint de Secrets Manager por 443."
  }

  assert {
    condition     = toset(keys(aws_ssm_parameter.layer)) == toset(["kms_key_arn", "postgres/security_group_id", "postgres/instance_id"]) && aws_ssm_parameter.layer["postgres/security_group_id"].name == "/acme/dev/data/postgres/security_group_id"
    error_message = "La capa publica el SG y el ID de la instancia para la capa app."
  }

  assert {
    condition     = local.backup_schedule.daily_retention_days == 7 && local.backup_schedule.continuous_retention_days == 0
    error_message = "Fuera de prod los backups son cortos y sin regla continua."
  }
}

run "prod_locks_the_vault_and_keeps_35_days" {
  command = plan

  variables {
    environment = "prod"
  }

  override_data {
    target = data.aws_ssm_parameters_by_path.network
    values = {
      names  = ["/acme/prod/network/vpc_id", "/acme/prod/network/vpc_cidr", "/acme/prod/network/subnet_ids/public", "/acme/prod/network/subnet_ids/app", "/acme/prod/network/subnet_ids/data", "/acme/prod/network/route_table_ids/app", "/acme/prod/network/route_table_ids/data", "/acme/prod/network/kms_key_arn", "/acme/prod/network/logs_bucket_name", "/acme/prod/network/logs_bucket_arn", "/acme/prod/network/endpoints_security_group_id", "/acme/prod/network/s3_prefix_list_id", "/acme/prod/network/alarm_topic_arn"]
      values = ["vpc-0123456789abcdef0", "10.20.0.0/16", "subnet-0aaaaaaaaaaaaaaa1,subnet-0aaaaaaaaaaaaaaa2", "subnet-0bbbbbbbbbbbbbbb1,subnet-0bbbbbbbbbbbbbbb2", "subnet-0ccccccccccccccc1,subnet-0ccccccccccccccc2", "rtb-0bbbbbbbbbbbbbbb1,rtb-0bbbbbbbbbbbbbbb2", "rtb-0ccccccccccccccc1,rtb-0ccccccccccccccc2", "arn:aws:kms:us-east-1:123456789012:key/11111111-2222-3333-4444-555555555555", "acme-dev-logs-123456789012", "arn:aws:s3:::acme-dev-logs-123456789012", "sg-0eeeeeeeeeeeeeee1", "pl-63a5400a", "arn:aws:sns:us-east-1:123456789012:acme-dev-alarms"]
    }
  }

  assert {
    condition     = local.backup_schedule.daily_retention_days == 35 && local.backup_schedule.continuous_retention_days == 35
    error_message = "En prod: 35 días y PITR continuo en AWS Backup."
  }
}
