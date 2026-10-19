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

mock_provider "aws" {
  alias = "us_east_1"

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
    defaults = { arn = "arn:aws:kms:us-east-1:123456789012:key/99999999-2222-3333-4444-555555555555" }
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
  mock_resource "aws_wafv2_web_acl" {
    defaults = { arn = "arn:aws:wafv2:us-east-1:123456789012:global/webacl/acme-dev/abcd" }
  }
  mock_resource "aws_cloudfront_distribution" {
    defaults = {
      arn            = "arn:aws:cloudfront::123456789012:distribution/E1ABCDEFGHIJKL"
      domain_name    = "d111111abcdef8.cloudfront.net"
      hosted_zone_id = "Z2FDTNDATAQYW2"
    }
  }
  mock_resource "aws_cloudfront_vpc_origin" {
    defaults = { id = "vo_0123456789abcdef" }
  }
  mock_resource "aws_cloudwatch_log_delivery_destination" {
    defaults = { arn = "arn:aws:logs:us-east-1:123456789012:delivery-destination:mock" }
  }
  mock_data "aws_security_group" {
    defaults = { id = "sg-0fedcba9876543210" }
  }
  mock_data "aws_ec2_managed_prefix_list" {
    defaults = { id = "pl-3b927c52" }
  }
}

override_data {
  target = data.aws_ssm_parameters_by_path.network
  values = {
    names  = ["/acme/dev/network/vpc_id", "/acme/dev/network/vpc_cidr", "/acme/dev/network/subnet_ids/public", "/acme/dev/network/subnet_ids/app", "/acme/dev/network/subnet_ids/data", "/acme/dev/network/route_table_ids/app", "/acme/dev/network/route_table_ids/data", "/acme/dev/network/kms_key_arn", "/acme/dev/network/logs_bucket_name", "/acme/dev/network/logs_bucket_arn", "/acme/dev/network/endpoints_security_group_id", "/acme/dev/network/s3_prefix_list_id", "/acme/dev/network/alarm_topic_arn"]
    values = ["vpc-0123456789abcdef0", "10.20.0.0/16", "subnet-0aaaaaaaaaaaaaaa1,subnet-0aaaaaaaaaaaaaaa2", "subnet-0bbbbbbbbbbbbbbb1,subnet-0bbbbbbbbbbbbbbb2", "subnet-0ccccccccccccccc1,subnet-0ccccccccccccccc2", "rtb-0bbbbbbbbbbbbbbb1,rtb-0bbbbbbbbbbbbbbb2", "rtb-0ccccccccccccccc1,rtb-0ccccccccccccccc2", "arn:aws:kms:us-east-1:123456789012:key/11111111-2222-3333-4444-555555555555", "acme-dev-logs-123456789012", "arn:aws:s3:::acme-dev-logs-123456789012", "sg-0eeeeeeeeeeeeeee1", "pl-63a5400a", "arn:aws:sns:us-east-1:123456789012:acme-dev-alarms"]
  }
}

override_data {
  target = data.aws_ssm_parameters_by_path.app
  values = {
    names  = ["/acme/dev/app/alb_arn", "/acme/dev/app/alb_dns_name", "/acme/dev/app/alb_security_group_id", "/acme/dev/app/service_security_group_id", "/acme/dev/app/task_role_arn", "/acme/dev/app/ecr_repository_url", "/acme/dev/app/cluster_name", "/acme/dev/app/service_name"]
    values = ["arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/acme-dev/50dc6c495c0c9188", "internal-acme-dev-123456.us-east-1.elb.amazonaws.com", "sg-0aaaaaaaaaaaaaaa9", "sg-0bbbbbbbbbbbbbbb9", "arn:aws:iam::123456789012:role/acme-dev-app-task", "123456789012.dkr.ecr.us-east-1.amazonaws.com/acme-dev-app", "acme-dev", "acme-dev-app"]
  }
}

variables {
  project     = "acme"
  environment = "dev"
  domain_name = "shop.example.com"
  zone_id     = "Z0123456789ABCDEFGHIJ"
}

run "edge_layer_composition" {
  command = plan

  assert {
    condition     = local.app["alb_arn"] == "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/acme-dev/50dc6c495c0c9188" && local.network["vpc_id"] == "vpc-0123456789abcdef0"
    error_message = "La capa edge lee el ALB y la VPC de SSM."
  }

  assert {
    condition     = length(module.viewer_certificate) == 1 && output.distribution_domain_name == "d111111abcdef8.cloudfront.net"
    error_message = "Se emite el certificado del viewer y se crea la distribución."
  }
}

run "optional_paid_waf_rules" {
  command = plan

  variables {
    waf = { bot_control = true, anti_ddos = true }
  }

  assert {
    condition     = output.web_acl_arn == "arn:aws:wafv2:us-east-1:123456789012:global/webacl/acme-dev/abcd"
    error_message = "Bot Control y Anti-DDoS son opcionales (coste por petición) y no cambian el Web ACL asociado."
  }
}

run "prod_requires_alarm_recipients" {
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
  override_data {
    target = data.aws_ssm_parameters_by_path.app
    values = {
      names  = ["/acme/prod/app/alb_arn", "/acme/prod/app/alb_dns_name", "/acme/prod/app/alb_security_group_id", "/acme/prod/app/service_security_group_id", "/acme/prod/app/task_role_arn", "/acme/prod/app/ecr_repository_url", "/acme/prod/app/cluster_name", "/acme/prod/app/service_name"]
      values = ["arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/acme-dev/50dc6c495c0c9188", "internal-acme-dev-123456.us-east-1.elb.amazonaws.com", "sg-0aaaaaaaaaaaaaaa9", "sg-0bbbbbbbbbbbbbbb9", "arn:aws:iam::123456789012:role/acme-dev-app-task", "123456789012.dkr.ecr.us-east-1.amazonaws.com/acme-dev-app", "acme-dev", "acme-dev-app"]
    }
  }

  expect_failures = [var.alarm_emails]
}

run "alb_ingress_rule_in_us_east_1_is_created_by_the_module" {
  command = plan

  assert {
    condition = (
      length(aws_vpc_security_group_ingress_rule.alb_from_cloudfront) == 0 &&
      length(data.aws_security_group.cloudfront_vpc_origins) == 0
    )
    error_message = "Con la aplicación en us-east-1 la regla de entrada del ALB la crea el módulo cdn."
  }
}

run "alb_ingress_rule_outside_us_east_1_is_created_by_the_layer" {
  command = plan

  override_data {
    target = data.aws_region.current
    values = { region = "eu-west-1" }
  }

  assert {
    condition = (
      length(aws_vpc_security_group_ingress_rule.alb_from_cloudfront) == 1 &&
      aws_vpc_security_group_ingress_rule.alb_from_cloudfront[0].from_port == 443 &&
      aws_vpc_security_group_ingress_rule.alb_from_cloudfront[0].ip_protocol == "tcp" &&
      length(data.aws_security_group.cloudfront_vpc_origins) == 1
    )
    error_message = "Fuera de us-east-1 la regla de entrada del ALB la crea la capa con el provider de la aplicación."
  }
}
