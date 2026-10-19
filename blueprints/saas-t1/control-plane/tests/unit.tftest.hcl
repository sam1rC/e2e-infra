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
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}", minified_json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
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
  mock_resource "aws_ce_anomaly_monitor" {
    defaults = { arn = "arn:aws:ce::123456789012:anomalymonitor/11111111-2222-3333-4444-555555555555" }
  }
  mock_resource "aws_organizations_account" {
    defaults = { id = "210987654321", arn = "arn:aws:organizations::123456789012:account/o-abcdefghij/210987654321" }
  }
  mock_resource "aws_organizations_organizational_unit" {
    defaults = { id = "ou-abcd-12345678", arn = "arn:aws:organizations::123456789012:ou/o-abcdefghij/ou-abcd-12345678" }
  }
}

variables {
  project     = "acme"
  environment = "dev"

  auth = {
    callback_urls = ["https://app.example.com/auth/callback"]
  }

  onboarding_function = {
    s3_bucket = "acme-dev-artifacts"
    s3_key    = "onboarding/app.zip"
  }

  app_account_ids = ["210987654321"]
}

run "pool_per_tier_by_default" {
  command = plan

  assert {
    condition     = toset(keys(module.pools)) == toset(["basic", "pro", "premium"]) && local.pool_prefix == "tier"
    error_message = "Por defecto, un user pool por tier."
  }

  assert {
    condition     = toset(keys(local.onboarding_policies)) == toset(["registry", "identity", "events"]) && !contains(keys(local.onboarding_environment), "GITHUB_REPOSITORY")
    error_message = "Sin pipeline de silos, la Lambda de onboarding no lee la GitHub App."
  }

  assert {
    condition     = toset(keys(aws_ssm_parameter.layer)) == toset(["issuers", "event_bus_arn", "registry_table_name"]) && aws_ssm_parameter.layer["issuers"].type == "StringList"
    error_message = "El control plane publica emisores, bus y registro."
  }
}

run "pool_per_tenant_with_silo_pipeline" {
  command = plan

  variables {
    pool_strategy = "per_tenant"
    pools         = ["bigclient", "acme2"]
    silo_pipeline = { repository = "acme/infra", workflow = "silo.yml" }
  }

  assert {
    condition     = local.pool_prefix == "tenant" && length(aws_secretsmanager_secret.github_app) == 1 && contains(keys(local.onboarding_policies), "github-app")
    error_message = "Con pools por tenant y pipeline de silos se crea el secreto de la GitHub App y su permiso."
  }
}

run "rejects_bad_pool_keys" {
  command = plan

  variables {
    pools = ["Big_Client"]
  }

  expect_failures = [var.pools]
}

run "prod_requires_alarm_recipients" {
  command = plan

  variables {
    environment = "prod"
    auth = {
      callback_urls = ["https://app.example.com/auth/callback"]
      email = {
        sending_account    = "DEVELOPER"
        source_arn         = "arn:aws:ses:us-east-1:123456789012:identity/example.com"
        from_email_address = "no-reply@example.com"
      }
    }
  }

  expect_failures = [var.alarm_emails]
}
