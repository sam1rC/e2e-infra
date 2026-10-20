mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  mock_resource "aws_cloudwatch_log_group" {
    defaults = {
      arn = "arn:aws:logs:us-east-1:123456789012:log-group:/aws/lambda/acme-prod-orders"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/acme-prod-orders"
    }
  }

  mock_resource "aws_sqs_queue" {
    defaults = {
      arn = "arn:aws:sqs:us-east-1:123456789012:acme-prod-orders-dlq"
    }
  }

  mock_resource "aws_lambda_code_signing_config" {
    defaults = {
      arn = "arn:aws:lambda:us-east-1:123456789012:code-signing-config:csc-0123456789abcdef0"
    }
  }
}

variables {
  project     = "acme"
  environment = "prod"
  name        = "orders"
  kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/11111111-2222-3333-4444-555555555555"

  runtime           = "python3.13"
  handler           = "app.handler"
  s3_bucket         = "acme-prod-artifacts-123456789012"
  s3_key            = "orders/1.4.2.zip"
  s3_object_version = "3HL4kqtJlcpXroDTDmJ.rVAn.k3V9Gbh"
}

run "function_is_arm64_traced_and_json_logged" {
  command = plan

  assert {
    condition = (
      aws_lambda_function.this.function_name == "acme-prod-orders" &&
      toset(aws_lambda_function.this.architectures) == toset(["arm64"]) &&
      aws_lambda_function.this.package_type == "Zip" &&
      aws_lambda_function.this.runtime == "python3.13" &&
      aws_lambda_function.this.handler == "app.handler" &&
      aws_lambda_function.this.kms_key_arn == var.kms_key_arn
    )
    error_message = "Función arm64, zip, con la CMK para las variables de entorno."
  }

  assert {
    condition = (
      alltrue([for t in aws_lambda_function.this.tracing_config : t.mode == "Active"]) &&
      length(aws_lambda_function.this.tracing_config) == 1
    )
    error_message = "El tracing nativo debe estar activo."
  }

  assert {
    condition = alltrue([
      for l in aws_lambda_function.this.logging_config :
      l.log_format == "JSON" && l.log_group == "/aws/lambda/acme-prod-orders" &&
      l.application_log_level == "INFO" && l.system_log_level == "WARN"
    ]) && length(aws_lambda_function.this.logging_config) == 1
    error_message = "Logs JSON hacia el log group del módulo."
  }
}

run "package_comes_from_s3_with_a_pinned_version" {
  command = plan

  assert {
    condition = (
      aws_lambda_function.this.s3_bucket == "acme-prod-artifacts-123456789012" &&
      aws_lambda_function.this.s3_key == "orders/1.4.2.zip" &&
      aws_lambda_function.this.s3_object_version == "3HL4kqtJlcpXroDTDmJ.rVAn.k3V9Gbh" &&
      aws_lambda_function.this.image_uri == null
    )
    error_message = "El código sale del objeto S3 versionado."
  }
}

run "container_image_mode" {
  command = plan

  variables {
    runtime           = null
    handler           = null
    s3_bucket         = null
    s3_key            = null
    s3_object_version = null
    image_uri         = "123456789012.dkr.ecr.us-east-1.amazonaws.com/acme-prod-orders@sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
  }

  assert {
    condition = (
      aws_lambda_function.this.package_type == "Image" &&
      aws_lambda_function.this.image_uri == var.image_uri &&
      aws_lambda_function.this.runtime == null &&
      aws_lambda_function.this.handler == null
    )
    error_message = "Modo imagen: package_type Image, sin runtime ni handler."
  }
}

run "log_group_is_encrypted_with_retention" {
  command = plan

  assert {
    condition = (
      aws_cloudwatch_log_group.this.name == "/aws/lambda/acme-prod-orders" &&
      aws_cloudwatch_log_group.this.kms_key_id == var.kms_key_arn &&
      aws_cloudwatch_log_group.this.retention_in_days == 90
    )
    error_message = "El log group debe tener CMK y retención."
  }
}

run "unreserved_concurrency_by_default_and_reservable" {
  command = plan

  assert {
    condition     = aws_lambda_function.this.reserved_concurrent_executions == -1
    error_message = "Sin reserva, concurrencia sin reservar (-1)."
  }
}

run "reserved_concurrency_is_applied" {
  command = plan

  variables {
    reserved_concurrent_executions = 25
  }

  assert {
    condition     = aws_lambda_function.this.reserved_concurrent_executions == 25
    error_message = "La concurrencia reservada debe aplicarse."
  }
}

run "environment_variables_are_optional" {
  command = plan

  assert {
    condition     = length(aws_lambda_function.this.environment) == 0
    error_message = "Sin variables, no hay bloque environment."
  }
}

run "environment_variables_are_set" {
  command = plan

  variables {
    environment_variables = { TABLE_NAME = "orders" }
  }

  assert {
    condition     = alltrue([for e in aws_lambda_function.this.environment : e.variables["TABLE_NAME"] == "orders"]) && length(aws_lambda_function.this.environment) == 1
    error_message = "Las variables de entorno deben pasarse."
  }
}

run "execution_role_is_scoped_not_the_managed_policy" {
  command = plan

  assert {
    condition = alltrue([
      for s in data.aws_iam_policy_document.base.statement :
      s.effect == "Allow" && alltrue([for a in s.actions : !endswith(a, ":*") && a != "*"])
    ])
    error_message = "Acciones explícitas, sin comodines."
  }

  assert {
    condition = anytrue([
      for s in data.aws_iam_policy_document.base.statement :
      s.sid == "WriteFunctionLogs" && toset(s.actions) == toset(["logs:CreateLogStream", "logs:PutLogEvents"]) && !contains(s.resources, "*")
    ])
    error_message = "Los logs solo se escriben en el log group de la función."
  }

  assert {
    condition = anytrue([
      for s in data.aws_iam_policy_document.base.statement :
      s.sid == "DecryptEnvironment" && toset(s.actions) == toset(["kms:Decrypt"]) && toset(s.resources) == toset([var.kms_key_arn])
    ])
    error_message = "kms:Decrypt solo sobre la CMK."
  }

  assert {
    condition = alltrue([
      for s in data.aws_iam_policy_document.base.statement :
      contains(["SendTraces"], s.sid) || !contains(s.resources, "*")
    ])
    error_message = "Sin VPC ni DLQ, solo X-Ray usa recurso *."
  }
}

run "trust_policy_is_the_lambda_service" {
  command = plan

  assert {
    condition = alltrue([
      for s in data.aws_iam_policy_document.assume.statement :
      toset(s.actions) == toset(["sts:AssumeRole"]) &&
      alltrue([for p in s.principals : p.type == "Service" && toset(p.identifiers) == toset(["lambda.amazonaws.com"])])
    ])
    error_message = "Solo el servicio Lambda asume el rol."
  }

  assert {
    condition = alltrue([
      for s in data.aws_iam_policy_document.assume.statement :
      length([for c in s.condition : c if c.test == "StringEquals" && c.variable == "aws:SourceAccount" && toset(c.values) == toset([data.aws_caller_identity.current.account_id])]) == 1
    ]) && length(data.aws_iam_policy_document.assume.statement) == 1
    error_message = "La trust policy limita la asunción a la propia cuenta (aws:SourceAccount)."
  }
}

run "injected_policies_and_boundary" {
  command = plan

  variables {
    policies = {
      table = jsonencode({
        Version   = "2012-10-17"
        Statement = [{ Effect = "Allow", Action = ["dynamodb:GetItem"], Resource = "arn:aws:dynamodb:us-east-1:123456789012:table/orders" }]
      })
    }
    permissions_boundary_arn = "arn:aws:iam::123456789012:policy/acme-boundary"
  }

  assert {
    condition = (
      toset(keys(aws_iam_role_policy.injected)) == toset(["table"]) &&
      aws_iam_role.this.permissions_boundary == "arn:aws:iam::123456789012:policy/acme-boundary"
    )
    error_message = "Las políticas inyectadas y la boundary deben aplicarse."
  }
}

run "no_vpc_by_default" {
  command = plan

  assert {
    condition = (
      length(aws_security_group.this) == 0 &&
      length(aws_lambda_function.this.vpc_config) == 0 &&
      length(aws_vpc_security_group_egress_rule.this) == 0
    )
    error_message = "Sin vpc_config no hay SG ni VPC."
  }
}

run "vpc_config_creates_a_closed_security_group" {
  command = plan

  variables {
    vpc_config = {
      vpc_id     = "vpc-0123456789abcdef0"
      subnet_ids = ["subnet-0aaaaaaaaaaaaaaaa", "subnet-0bbbbbbbbbbbbbbbb"]
      egress_rules = {
        db = { description = "PostgreSQL", port = 5432, security_group_id = "sg-0dddddddddddddddd" }
      }
    }
  }

  assert {
    condition = (
      length(aws_security_group.this) == 1 &&
      alltrue([
        for v in aws_lambda_function.this.vpc_config :
        toset(v.subnet_ids) == toset(["subnet-0aaaaaaaaaaaaaaaa", "subnet-0bbbbbbbbbbbbbbbb"]) && length(v.security_group_ids) == 1
      ]) && length(aws_lambda_function.this.vpc_config) == 1
    )
    error_message = "La función debe correr en las subredes indicadas con su propio SG."
  }

  assert {
    condition = (
      toset(keys(aws_vpc_security_group_egress_rule.this)) == toset(["db"]) &&
      aws_vpc_security_group_egress_rule.this["db"].referenced_security_group_id == "sg-0dddddddddddddddd" &&
      aws_vpc_security_group_egress_rule.this["db"].from_port == 5432 &&
      aws_vpc_security_group_egress_rule.this["db"].cidr_ipv4 == null
    )
    error_message = "La única salida es la declarada."
  }

  assert {
    condition = anytrue([
      for s in data.aws_iam_policy_document.base.statement :
      s.sid == "ManageVpcNetworkInterfaces" && contains(s.actions, "ec2:CreateNetworkInterface") && !contains(s.actions, "ec2:*")
    ])
    error_message = "El rol necesita los permisos de interfaces de red, explícitos."
  }
}

run "no_dlq_by_default" {
  command = plan

  assert {
    condition = (
      length(aws_sqs_queue.dlq) == 0 &&
      length(aws_lambda_function.this.dead_letter_config) == 0 &&
      output.dlq_arn == null
    )
    error_message = "Sin enable_dlq no hay cola ni dead_letter_config."
  }
}

run "dlq_is_encrypted_and_wired" {
  command = plan

  variables {
    enable_dlq         = true
    dlq_retention_days = 7
  }

  assert {
    condition = (
      length(aws_sqs_queue.dlq) == 1 &&
      aws_sqs_queue.dlq[0].name == "acme-prod-orders-dlq" &&
      aws_sqs_queue.dlq[0].kms_master_key_id == var.kms_key_arn &&
      aws_sqs_queue.dlq[0].message_retention_seconds == 604800
    )
    error_message = "La DLQ debe cifrarse con la CMK y respetar la retención."
  }

  assert {
    condition = (
      length(aws_lambda_function.this.dead_letter_config) == 1 &&
      anytrue([
        for s in data.aws_iam_policy_document.base.statement :
        s.sid == "SendToDeadLetterQueue" && toset(s.actions) == toset(["sqs:SendMessage"]) && !contains(s.resources, "*")
      ])
    )
    error_message = "La función envía a la DLQ con sqs:SendMessage acotado a la cola."
  }
}

run "no_code_signing_by_default" {
  command = plan

  assert {
    condition     = length(aws_lambda_code_signing_config.this) == 0
    error_message = "Sin code_signing no hay configuración de firma."
  }
}

run "code_signing_enforces_trusted_publishers" {
  command = plan

  variables {
    code_signing = {
      signing_profile_version_arns = ["arn:aws:signer:us-east-1:123456789012:/signing-profiles/acme_lambda/AbCdEf1234"]
    }
  }

  assert {
    condition = (
      length(aws_lambda_code_signing_config.this) == 1 &&
      alltrue([for p in aws_lambda_code_signing_config.this[0].policies : p.untrusted_artifact_on_deployment == "Enforce"]) &&
      alltrue([
        for a in aws_lambda_code_signing_config.this[0].allowed_publishers :
        toset(a.signing_profile_version_arns) == toset(["arn:aws:signer:us-east-1:123456789012:/signing-profiles/acme_lambda/AbCdEf1234"])
      ])
    )
    error_message = "La firma debe exigirse (Enforce) con los perfiles indicados."
  }
}

run "x86_is_selectable" {
  command = plan

  variables {
    architecture = "x86_64"
  }

  assert {
    condition     = toset(aws_lambda_function.this.architectures) == toset(["x86_64"])
    error_message = "architecture debe poder ser x86_64."
  }
}

run "rejects_deprecated_runtime" {
  command = plan

  variables {
    runtime = "python3.8"
  }

  expect_failures = [var.runtime]
}

run "rejects_image_by_tag" {
  command = plan

  variables {
    runtime           = null
    handler           = null
    s3_bucket         = null
    s3_key            = null
    s3_object_version = null
    image_uri         = "123456789012.dkr.ecr.us-east-1.amazonaws.com/acme-prod-orders:latest"
  }

  expect_failures = [var.image_uri]
}

run "rejects_zip_and_image_together" {
  command = plan

  variables {
    image_uri = "123456789012.dkr.ecr.us-east-1.amazonaws.com/acme-prod-orders@sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
  }

  expect_failures = [var.image_uri]
}

run "rejects_zip_without_handler" {
  command = plan

  variables {
    handler = null
  }

  expect_failures = [var.image_uri]
}

run "rejects_short_log_retention_in_prod" {
  command = plan

  variables {
    log_retention_days = 30
  }

  expect_failures = [var.log_retention_days]
}

run "rejects_kms_alias" {
  command = plan

  variables {
    kms_key_arn = "arn:aws:kms:us-east-1:123456789012:alias/lambda"
  }

  expect_failures = [var.kms_key_arn]
}

run "rejects_egress_rule_without_destination" {
  command = plan

  variables {
    vpc_config = {
      vpc_id       = "vpc-0123456789abcdef0"
      subnet_ids   = ["subnet-0aaaaaaaaaaaaaaaa"]
      egress_rules = { bad = { description = "x", port = 443 } }
    }
  }

  expect_failures = [var.vpc_config]
}

run "rejects_code_signing_with_image" {
  command = plan

  variables {
    runtime           = null
    handler           = null
    s3_bucket         = null
    s3_key            = null
    s3_object_version = null
    image_uri         = "123456789012.dkr.ecr.us-east-1.amazonaws.com/acme-prod-orders@sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
    code_signing = {
      signing_profile_version_arns = ["arn:aws:signer:us-east-1:123456789012:/signing-profiles/acme_lambda/AbCdEf1234"]
    }
  }

  expect_failures = [var.code_signing]
}

run "rejects_timeout_over_15_minutes" {
  command = plan

  variables {
    timeout_seconds = 901
  }

  expect_failures = [var.timeout_seconds]
}
