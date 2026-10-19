mock_provider "aws" {
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }

  mock_resource "aws_organizations_account" {
    defaults = {
      id  = "210987654321"
      arn = "arn:aws:organizations::123456789012:account/o-abcdefghij/210987654321"
    }
  }
}

variables {
  project     = "acme"
  environment = "prod"
  account_key = "silo-tenant1"
  email       = "aws+acme-silo-tenant1@example.com"
  parent_id   = "ou-abcd-12345678"
}

run "safe_defaults" {
  command = plan

  assert {
    condition = (
      aws_organizations_account.this.name == "acme-silo-tenant1" &&
      aws_organizations_account.this.parent_id == "ou-abcd-12345678" &&
      aws_organizations_account.this.iam_user_access_to_billing == "DENY" &&
      aws_organizations_account.this.close_on_deletion == false &&
      aws_organizations_account.this.role_name == "OrganizationAccountAccessRole"
    )
    error_message = "Por defecto: nombre <project>-<account_key>, sin facturación para IAM y sin cerrar la cuenta al destruir."
  }

  assert {
    condition     = aws_organizations_account.this.tags["AccountKey"] == "silo-tenant1" && aws_organizations_account.this.tags["Environment"] == "prod"
    error_message = "La cuenta lleva las etiquetas AccountKey y Environment."
  }
}

run "outputs_the_bootstrap_role" {
  command = apply

  assert {
    condition     = output.account_id == "210987654321" && output.bootstrap_role_arn == "arn:aws:iam::210987654321:role/OrganizationAccountAccessRole"
    error_message = "El rol de bootstrap es arn:<partición>:iam::<cuenta>:role/<role_name>."
  }
}

run "explicit_name" {
  command = plan

  variables {
    name = "Acme Tenant One"
  }

  assert {
    condition     = aws_organizations_account.this.name == "Acme Tenant One"
    error_message = "name sustituye al nombre por defecto."
  }
}

run "rejects_invalid_email" {
  command = plan

  variables {
    email = "not-an-email"
  }

  expect_failures = [var.email]
}

run "rejects_invalid_parent" {
  command = plan

  variables {
    parent_id = "123456789012"
  }

  expect_failures = [var.parent_id]
}

run "rejects_unknown_billing_mode" {
  command = plan

  variables {
    iam_user_access_to_billing = "MAYBE"
  }

  expect_failures = [var.iam_user_access_to_billing]
}

run "rejects_invalid_account_key" {
  command = plan

  variables {
    account_key = "Silo_Tenant"
  }

  expect_failures = [var.account_key]
}
