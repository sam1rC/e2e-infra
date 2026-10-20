mock_provider "aws" {
  # Un JSON válido: aws_iam_role rechaza el texto aleatorio que genera el mock.
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }

  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::210987654321:role/acme-prod-silo-deploy" }
  }
}

variables {
  project           = "acme"
  environment       = "prod"
  name              = "silo-deploy"
  trusted_role_arns = ["arn:aws:iam::111111111111:role/gha-apply-prod"]

  managed_policy_arns = {
    admin = "arn:aws:iam::aws:policy/AdministratorAccess"
  }
}

run "trusts_only_the_listed_roles" {
  command = plan

  assert {
    condition = alltrue([
      for s in data.aws_iam_policy_document.trust.statement :
      toset(s.actions) == toset(["sts:AssumeRole"]) &&
      alltrue([for p in s.principals : p.type == "AWS" && toset(p.identifiers) == toset(["arn:aws:iam::111111111111:role/gha-apply-prod"])])
    ])
    error_message = "La confianza solo admite sts:AssumeRole desde los roles indicados."
  }

  assert {
    condition     = aws_iam_role.this.name == "acme-prod-silo-deploy" && aws_iam_role.this.max_session_duration == 3600
    error_message = "Nombre <project>-<env>-<name> y sesiones de 1 hora por defecto."
  }

  assert {
    condition     = length(aws_iam_role_policy_attachment.managed) == 1 && length(aws_iam_role_policy.inline) == 0
    error_message = "Se adjunta la política gestionada indicada."
  }
}

run "third_party_access_requires_external_id_and_mfa" {
  command = plan

  variables {
    name              = "provider-access"
    external_id       = "acme-support-2026"
    require_mfa       = true
    organization_id   = "o-abcdefghij"
    allow_tag_session = true
  }

  assert {
    condition = alltrue([
      for s in data.aws_iam_policy_document.trust.statement :
      toset([for c in s.condition : c.variable]) == toset(["sts:ExternalId", "aws:PrincipalOrgID", "aws:MultiFactorAuthPresent"]) &&
      contains(s.actions, "sts:TagSession")
    ])
    error_message = "ExternalId, organización y MFA se añaden como condiciones de la confianza."
  }
}

run "rejects_account_root" {
  command = plan

  variables {
    trusted_role_arns = ["arn:aws:iam::111111111111:root"]
  }

  expect_failures = [var.trusted_role_arns]
}

run "rejects_wildcards" {
  command = plan

  variables {
    trusted_role_arns = ["arn:aws:iam::111111111111:role/*"]
  }

  expect_failures = [var.trusted_role_arns]
}

run "rejects_role_without_policies" {
  command = plan

  variables {
    managed_policy_arns = {}
  }

  expect_failures = [var.inline_policies]
}

run "rejects_invalid_external_id" {
  command = plan

  variables {
    external_id = "a b"
  }

  expect_failures = [var.external_id]
}

run "rejects_long_sessions" {
  command = plan

  variables {
    max_session_duration = 86400
  }

  expect_failures = [var.max_session_duration]
}
