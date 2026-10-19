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

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  project         = "acme"
  environment     = "dev"
  vpc_id          = "vpc-0123456789abcdef0"
  vpc_cidr_block  = "10.20.0.0/16"
  subnet_ids      = ["subnet-aaaa", "subnet-bbbb"]
  route_table_ids = ["rtb-app-a", "rtb-app-b", "rtb-data-a"]

  allowed_security_group_ids = {
    app = "sg-0123456789abcdef0"
  }
}

run "default_interface_services" {
  command = plan

  assert {
    condition = toset(keys(aws_vpc_endpoint.interface)) == toset([
      "ecr.api", "ecr.dkr", "logs", "secretsmanager", "sts", "kms",
    ])
    error_message = "Los endpoints de interfaz por defecto son ecr.api, ecr.dkr, logs, secretsmanager, sts y kms."
  }

  assert {
    condition = alltrue([
      for e in aws_vpc_endpoint.interface :
      e.vpc_endpoint_type == "Interface" && e.private_dns_enabled && length(e.subnet_ids) == 2
    ])
    error_message = "Interfaces con DNS privado en las subredes app."
  }

  assert {
    condition     = aws_vpc_endpoint.interface["sts"].service_name == "com.amazonaws.us-east-1.sts"
    error_message = "El nombre de servicio debe incluir la región."
  }
}

run "optional_services_are_added" {
  command = plan

  variables {
    interface_services = ["ecr.api", "ecr.dkr", "logs", "xray", "ssm"]
  }

  assert {
    condition     = length(aws_vpc_endpoint.interface) == 5 && contains(keys(aws_vpc_endpoint.interface), "xray")
    error_message = "Debe poder añadirse xray y ssm."
  }
}

run "gateway_endpoints_for_s3_and_dynamodb_on_given_route_tables" {
  command = plan

  assert {
    condition     = toset(keys(aws_vpc_endpoint.gateway)) == toset(["s3", "dynamodb"])
    error_message = "Deben existir endpoints gateway de S3 y DynamoDB."
  }

  assert {
    condition = alltrue([
      for e in aws_vpc_endpoint.gateway : e.vpc_endpoint_type == "Gateway" && length(e.route_table_ids) == 3
    ])
    error_message = "Los endpoints gateway se asocian a todas las tablas de rutas indicadas."
  }
}

run "s3_policy_limits_buckets_to_own_account_and_ecr_layers" {
  command = plan

  assert {
    condition = anytrue([
      for s in data.aws_iam_policy_document.s3.statement :
      s.sid == "AllowBucketsOfAllowedAccounts" && anytrue([
        for c in s.condition : c.variable == "aws:ResourceAccount" && toset(c.values) == toset(["123456789012"])
      ])
    ])
    error_message = "El endpoint de S3 solo debe permitir buckets de la cuenta actual."
  }

  assert {
    condition = anytrue([
      for s in data.aws_iam_policy_document.s3.statement :
      contains(s.resources, "arn:aws:s3:::prod-us-east-1-starport-layer-bucket/*")
    ])
    error_message = "Debe permitirse el bucket de capas de ECR de la región."
  }
}

run "s3_policy_accepts_extra_accounts_and_buckets" {
  command = plan

  variables {
    s3_allowed_account_ids    = ["210987654321"]
    s3_additional_bucket_arns = ["arn:aws:s3:::amazonlinux-2-repos-us-east-1"]
  }

  assert {
    condition = anytrue([
      for s in data.aws_iam_policy_document.s3.statement :
      anytrue([for c in s.condition : c.variable == "aws:ResourceAccount" && toset(c.values) == toset(["123456789012", "210987654321"])])
    ])
    error_message = "Las cuentas adicionales se añaden a la actual."
  }

  assert {
    condition = anytrue([
      for s in data.aws_iam_policy_document.s3.statement :
      contains(s.resources, "arn:aws:s3:::amazonlinux-2-repos-us-east-1/*")
    ])
    error_message = "Los buckets adicionales se añaden a la lectura permitida."
  }
}

run "dynamodb_policy_limited_to_account_tables" {
  command = plan

  assert {
    condition = alltrue([
      for s in data.aws_iam_policy_document.dynamodb.statement :
      toset(s.resources) == toset(["arn:aws:dynamodb:us-east-1:123456789012:table/*"])
    ])
    error_message = "El endpoint de DynamoDB solo debe alcanzar tablas de la cuenta en la región."
  }
}

run "security_group_admits_only_the_given_security_groups" {
  command = plan

  assert {
    condition = (
      length(aws_vpc_security_group_ingress_rule.from_app_security_groups) == 1 &&
      length(aws_vpc_security_group_ingress_rule.from_vpc_cidr) == 0 &&
      alltrue([
        for r in aws_vpc_security_group_ingress_rule.from_app_security_groups :
        r.from_port == 443 && r.to_port == 443 && r.ip_protocol == "tcp" && r.cidr_ipv4 == null
      ])
    )
    error_message = "Por defecto solo entra 443 desde los security groups indicados, sin CIDR."
  }
}

run "several_security_groups_get_one_rule_each" {
  command = plan

  variables {
    allowed_security_group_ids = {
      app    = "sg-aaaa"
      worker = "sg-bbbb"
    }
  }

  assert {
    condition     = toset(keys(aws_vpc_security_group_ingress_rule.from_app_security_groups)) == toset(["app", "worker"])
    error_message = "Una regla por security group, con clave estable por nombre."
  }
}

run "vpc_cidr_fallback_is_explicit" {
  command = plan

  variables {
    allowed_security_group_ids = {}
    vpc_cidr_fallback          = true
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.from_vpc_cidr) == 1 && aws_vpc_security_group_ingress_rule.from_vpc_cidr[0].cidr_ipv4 == "10.20.0.0/16"
    error_message = "El fallback permite 443 desde el CIDR de la VPC, nunca 0.0.0.0/0."
  }
}

run "rejects_unreachable_endpoints" {
  command = plan

  variables {
    allowed_security_group_ids = {}
  }

  expect_failures = [var.vpc_cidr_fallback]
}

run "consumer_layers_may_add_the_ingress_rules" {
  command = plan

  variables {
    allowed_security_group_ids = {}
    ingress_from_other_layers  = true
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.from_app_security_groups) == 0 && length(aws_vpc_security_group_ingress_rule.from_vpc_cidr) == 0
    error_message = "Sin SG autorizados ni fallback, el módulo no crea reglas de entrada: las añaden las capas consumidoras."
  }
}

run "rejects_single_subnet" {
  command = plan

  variables {
    subnet_ids = ["subnet-aaaa"]
  }

  expect_failures = [var.subnet_ids]
}

run "rejects_unknown_gateway_service" {
  command = plan

  variables {
    gateway_services = ["s3", "sqs"]
  }

  expect_failures = [var.gateway_services]
}

run "rejects_duplicate_interface_services" {
  command = plan

  variables {
    interface_services = ["logs", "logs"]
  }

  expect_failures = [var.interface_services]
}

run "rejects_invalid_vpc_id" {
  command = plan

  variables {
    vpc_id = "not-a-vpc"
  }

  expect_failures = [var.vpc_id]
}

run "rejects_invalid_extra_account" {
  command = plan

  variables {
    s3_allowed_account_ids = ["1234"]
  }

  expect_failures = [var.s3_allowed_account_ids]
}
