mock_provider "aws" {
  # El mock devuelve un mapa vacío de outputs: la plantilla expone RotationLambdaARN.
  mock_resource "aws_cloudformation_stack" {
    defaults = {
      outputs = {
        RotationLambdaARN = "arn:aws:lambda:us-east-1:123456789012:function:acme-dev-aurora-rotation"
      }
    }
  }
}

variables {
  environment          = "dev"
  name                 = "acme-dev-aurora"
  vpc_id               = "vpc-0123456789abcdef0"
  db_security_group_id = "sg-0aaaaaaaaaaaaaaaa"
  kms_key_arn          = "arn:aws:kms:us-east-1:123456789012:key/11111111-2222-3333-4444-555555555555"
  master_secret_arn    = "arn:aws:secretsmanager:us-east-1:123456789012:secret:rds!cluster-abc-AbCdEf"
  db_host              = "acme-dev-aurora.cluster-abc.us-east-1.rds.amazonaws.com"
}

run "secret_is_empty_cmk_encrypted_and_named_after_prefix" {
  command = plan

  assert {
    condition = (
      aws_secretsmanager_secret.app_runtime.name == "acme-dev-aurora/app_runtime" &&
      aws_secretsmanager_secret.app_runtime.kms_key_id == var.kms_key_arn &&
      aws_secretsmanager_secret.app_runtime.recovery_window_in_days == 7
    )
    error_message = "El secreto debe llamarse <name>/app_runtime, cifrarse con la CMK y tener 7 días de recuperación fuera de prod."
  }
}

run "without_rotation_only_the_secret_exists" {
  command = plan

  assert {
    condition = (
      length(aws_cloudformation_stack.rotation) == 0 &&
      length(aws_security_group.rotation) == 0 &&
      length(aws_vpc_security_group_ingress_rule.db_from_rotation) == 0
    )
    error_message = "Sin rotation no debe crearse ningún recurso de rotación."
  }
}

run "rotation_deploys_hosted_multiuser_function_in_vpc" {
  command = apply

  variables {
    rotation = {
      subnet_ids                 = ["subnet-0aaaaaaaaaaaaaaaa", "subnet-0bbbbbbbbbbbbbbbb"]
      endpoint_security_group_id = "sg-0bbbbbbbbbbbbbbbb"
    }
  }

  assert {
    condition = (
      aws_cloudformation_stack.rotation[0].name == "acme-dev-aurora-rotation" &&
      toset(aws_cloudformation_stack.rotation[0].capabilities) == toset(["CAPABILITY_IAM", "CAPABILITY_AUTO_EXPAND"]) &&
      jsondecode(aws_cloudformation_stack.rotation[0].template_body).Transform == "AWS::SecretsManager-2024-09-16"
    )
    error_message = "La rotación debe desplegarse con la transformación de Secrets Manager (HostedRotationLambda) y sus capabilities."
  }

  assert {
    condition = (
      jsondecode(aws_cloudformation_stack.rotation[0].template_body).Resources.RotationSchedule.Properties.HostedRotationLambda.RotationType == "PostgreSQLMultiUser" &&
      jsondecode(aws_cloudformation_stack.rotation[0].template_body).Resources.RotationSchedule.Properties.HostedRotationLambda.RotationLambdaName == "acme-dev-aurora-rotation" &&
      jsondecode(aws_cloudformation_stack.rotation[0].template_body).Resources.RotationSchedule.Properties.HostedRotationLambda.VpcSubnetIds == "subnet-0aaaaaaaaaaaaaaaa,subnet-0bbbbbbbbbbbbbbbb" &&
      jsondecode(aws_cloudformation_stack.rotation[0].template_body).Resources.RotationSchedule.Properties.HostedRotationLambda.MasterSecretArn == var.master_secret_arn &&
      jsondecode(aws_cloudformation_stack.rotation[0].template_body).Resources.RotationSchedule.Properties.HostedRotationLambda.KmsKeyArn == var.kms_key_arn
    )
    error_message = "La función de rotación multiusuario recibe el secreto maestro, la CMK y las subredes indicadas."
  }

  assert {
    condition = (
      jsondecode(aws_cloudformation_stack.rotation[0].template_body).Resources.RotationSchedule.Properties.RotateImmediatelyOnUpdate == false &&
      jsondecode(aws_cloudformation_stack.rotation[0].template_body).Resources.RotationSchedule.Properties.RotationRules.AutomaticallyAfterDays == 30
    )
    error_message = "La rotación no debe ser inmediata (el secreto está vacío) y debe repetirse cada 30 días por defecto."
  }
}

run "rotation_security_group_has_only_two_egress_rules_and_db_ingress" {
  command = plan

  variables {
    rotation = {
      subnet_ids                 = ["subnet-0aaaaaaaaaaaaaaaa", "subnet-0bbbbbbbbbbbbbbbb"]
      endpoint_security_group_id = "sg-0bbbbbbbbbbbbbbbb"
    }
  }

  assert {
    condition = (
      aws_vpc_security_group_egress_rule.rotation_to_db[0].referenced_security_group_id == "sg-0aaaaaaaaaaaaaaaa" &&
      aws_vpc_security_group_egress_rule.rotation_to_db[0].from_port == 5432 &&
      aws_vpc_security_group_egress_rule.rotation_to_secretsmanager[0].referenced_security_group_id == "sg-0bbbbbbbbbbbbbbbb" &&
      aws_vpc_security_group_egress_rule.rotation_to_secretsmanager[0].to_port == 443
    )
    error_message = "La función solo debe poder salir hacia la BD (5432) y hacia el endpoint de Secrets Manager (443), por SG."
  }

  assert {
    condition = (
      aws_vpc_security_group_ingress_rule.db_from_rotation[0].security_group_id == "sg-0aaaaaaaaaaaaaaaa" &&
      aws_vpc_security_group_ingress_rule.db_from_rotation[0].cidr_ipv4 == null
    )
    error_message = "La BD solo debe aceptar a la función de rotación por referencia de SG, sin CIDR."
  }
}

run "prod_defaults_to_30_day_recovery_window" {
  command = plan

  variables {
    environment = "prod"
    rotation = {
      subnet_ids                 = ["subnet-0aaaaaaaaaaaaaaaa", "subnet-0bbbbbbbbbbbbbbbb"]
      endpoint_security_group_id = "sg-0bbbbbbbbbbbbbbbb"
    }
  }

  assert {
    condition     = aws_secretsmanager_secret.app_runtime.recovery_window_in_days == 30
    error_message = "En prod la ventana de recuperación por defecto debe ser de 30 días."
  }
}

run "immediate_deletion_allowed_outside_prod" {
  command = plan

  variables {
    recovery_window_in_days = 0
  }

  assert {
    condition     = aws_secretsmanager_secret.app_runtime.recovery_window_in_days == 0
    error_message = "Fuera de prod se admite 0 (borrado inmediato) para sandbox y pruebas."
  }
}

run "rejects_immediate_deletion_in_prod" {
  command = plan

  variables {
    environment             = "prod"
    recovery_window_in_days = 0
    rotation = {
      subnet_ids                 = ["subnet-0aaaaaaaaaaaaaaaa", "subnet-0bbbbbbbbbbbbbbbb"]
      endpoint_security_group_id = "sg-0bbbbbbbbbbbbbbbb"
    }
  }

  expect_failures = [var.recovery_window_in_days]
}

run "rejects_prod_without_rotation" {
  command = plan

  variables {
    environment = "prod"
  }

  expect_failures = [var.rotation]
}

run "rejects_rotation_without_master_secret" {
  command = plan

  variables {
    master_secret_arn = null
    rotation = {
      subnet_ids                 = ["subnet-0aaaaaaaaaaaaaaaa", "subnet-0bbbbbbbbbbbbbbbb"]
      endpoint_security_group_id = "sg-0bbbbbbbbbbbbbbbb"
    }
  }

  expect_failures = [var.rotation]
}

run "rejects_rotation_in_a_single_subnet" {
  command = plan

  variables {
    rotation = {
      subnet_ids                 = ["subnet-0aaaaaaaaaaaaaaaa"]
      endpoint_security_group_id = "sg-0bbbbbbbbbbbbbbbb"
    }
  }

  expect_failures = [var.rotation]
}

run "rejects_alias_as_kms_key" {
  command = plan

  variables {
    kms_key_arn = "arn:aws:kms:us-east-1:123456789012:alias/acme"
  }

  expect_failures = [var.kms_key_arn]
}

run "rejects_invalid_db_security_group" {
  command = plan

  variables {
    db_security_group_id = "not-a-sg"
  }

  expect_failures = [var.db_security_group_id]
}

run "initial_version_holds_only_connection_metadata" {
  command = plan

  assert {
    condition     = aws_secretsmanager_secret_version.initial.secret_string_wo_version == 1
    error_message = "La versión inicial se escribe una vez (write-only): las rotaciones no generan drift."
  }
}

run "rotation_requires_db_host" {
  command = plan

  variables {
    db_host = null
    rotation = {
      subnet_ids                 = ["subnet-0aaaaaaaaaaaaaaaa", "subnet-0bbbbbbbbbbbbbbbb"]
      endpoint_security_group_id = "sg-0bbbbbbbbbbbbbbbb"
    }
  }

  expect_failures = [var.rotation]
}

run "rotation_log_group_is_precreated_with_cmk" {
  command = plan

  variables {
    rotation = {
      subnet_ids                 = ["subnet-0aaaaaaaaaaaaaaaa", "subnet-0bbbbbbbbbbbbbbbb"]
      endpoint_security_group_id = "sg-0bbbbbbbbbbbbbbbb"
    }
  }

  assert {
    condition     = aws_cloudwatch_log_group.rotation[0].name == "/aws/lambda/acme-dev-aurora-rotation" && aws_cloudwatch_log_group.rotation[0].kms_key_id == var.kms_key_arn && aws_cloudwatch_log_group.rotation[0].retention_in_days == 90
    error_message = "El log group de la función de rotación se crea antes, cifrado y con retención."
  }
}
