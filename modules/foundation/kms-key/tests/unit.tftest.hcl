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

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  project     = "acme"
  environment = "dev"
  purpose     = "data"
}

run "secure_defaults" {
  command = plan

  assert {
    condition     = aws_kms_key.this.enable_key_rotation == true
    error_message = "La rotación anual debe estar activada por defecto."
  }

  assert {
    condition     = aws_kms_key.this.rotation_period_in_days == 365
    error_message = "El periodo de rotación debe ser 365 días."
  }

  assert {
    condition     = aws_kms_key.this.deletion_window_in_days == 30
    error_message = "La ventana de borrado por defecto debe ser 30 días."
  }

  assert {
    condition     = aws_kms_key.this.multi_region == false
    error_message = "La clave no debe ser multi-región por defecto."
  }
}

run "alias_follows_naming_convention" {
  command = plan

  assert {
    condition     = aws_kms_alias.this.name == "alias/acme-dev-data"
    error_message = "El alias debe ser alias/<project>-<environment>-<purpose>."
  }
}

run "policy_only_has_root_statement_by_default" {
  command = plan

  assert {
    condition     = length(data.aws_iam_policy_document.this.statement) == 1
    error_message = "Sin principals adicionales solo debe existir la declaración de raíz."
  }
}

run "policy_statements_follow_inputs" {
  command = plan

  variables {
    admin_principal_arns = ["arn:aws:iam::123456789012:role/admin"]
    user_principal_arns  = ["arn:aws:iam::123456789012:role/app"]
    service_principals   = ["logs.us-east-1.amazonaws.com"]
    via_services         = ["s3.us-east-1.amazonaws.com"]
  }

  assert {
    condition     = length(data.aws_iam_policy_document.this.statement) == 5
    error_message = "Debe haber raíz + admin + usuarios + servicios + vía servicio."
  }
}

run "additional_documents_are_merged" {
  command = plan

  variables {
    additional_policy_documents = ["{\"Version\":\"2012-10-17\",\"Statement\":[{\"Sid\":\"Extra\",\"Effect\":\"Allow\",\"Action\":\"kms:DescribeKey\",\"Resource\":\"*\",\"Principal\":{\"Service\":\"cloudtrail.amazonaws.com\"}}]}"]
  }

  assert {
    condition     = length(data.aws_iam_policy_document.this.source_policy_documents) == 1
    error_message = "Los documentos adicionales deben pasarse a la key policy."
  }
}

run "rejects_invalid_environment" {
  command = plan

  variables {
    environment = "qa"
  }

  expect_failures = [var.environment]
}

run "rejects_short_deletion_window" {
  command = plan

  variables {
    deletion_window_in_days = 3
  }

  expect_failures = [var.deletion_window_in_days]
}
