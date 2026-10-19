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

  mock_data "aws_iam_openid_connect_provider" {
    defaults = {
      arn = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
    }
  }

  mock_resource "aws_iam_policy" {
    defaults = {
      arn = "arn:aws:iam::123456789012:policy/mock"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/mock"
    }
  }

  mock_resource "aws_iam_openid_connect_provider" {
    defaults = {
      arn = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  project           = "acme"
  environment       = "prod"
  github_org        = "acme-corp"
  github_repo       = "acme-infra"
  state_bucket_arn  = "arn:aws:s3:::acme-prod-tfstate-123456789012"
  state_kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/11111111-2222-3333-4444-555555555555"
}

run "apply_role_trusts_only_the_github_environment" {
  command = plan

  assert {
    condition = flatten([
      for s in data.aws_iam_policy_document.apply_trust.statement : [
        for c in s.condition : c.values if endswith(c.variable, ":sub")
      ]
    ]) == ["repo:acme-corp/acme-infra:environment:prod"]
    error_message = "El rol de apply solo puede confiar en el sub del GitHub Environment."
  }
}

run "apply_role_trusts_custom_environment_name" {
  command = plan

  variables {
    github_environment = "prod-approvals"
  }

  assert {
    condition = flatten([
      for s in data.aws_iam_policy_document.apply_trust.statement : [
        for c in s.condition : c.values if endswith(c.variable, ":sub")
      ]
    ]) == ["repo:acme-corp/acme-infra:environment:prod-approvals"]
    error_message = "github_environment debe sustituir al nombre del entorno en el sub."
  }
}

run "plan_role_trusts_pull_requests_and_main_only" {
  command = plan

  assert {
    condition = toset(flatten([
      for s in data.aws_iam_policy_document.plan_trust.statement : [
        for c in s.condition : c.values if endswith(c.variable, ":sub")
      ]
      ])) == toset([
      "repo:acme-corp/acme-infra:pull_request",
      "repo:acme-corp/acme-infra:ref:refs/heads/main",
    ])
    error_message = "El rol de plan solo confía en pull_request y la rama principal."
  }
}

run "trust_policies_require_sts_audience" {
  command = plan

  assert {
    condition = alltrue([
      for doc in [data.aws_iam_policy_document.plan_trust, data.aws_iam_policy_document.apply_trust] :
      alltrue([
        for s in doc.statement : contains(flatten([for c in s.condition : c.values if endswith(c.variable, ":aud")]), "sts.amazonaws.com")
      ])
    ])
    error_message = "Ambas trust policies deben exigir aud = sts.amazonaws.com."
  }
}

run "roles_follow_naming_and_session_limits" {
  command = plan

  assert {
    condition     = aws_iam_role.plan.name == "gha-plan-prod" && aws_iam_role.apply.name == "gha-apply-prod"
    error_message = "Los roles deben llamarse gha-plan-<env> y gha-apply-<env>."
  }

  assert {
    condition     = aws_iam_role.plan.max_session_duration == 3600 && aws_iam_role.apply.max_session_duration == 3600
    error_message = "max_session_duration debe ser 3600."
  }
}

run "apply_role_has_permission_boundary" {
  command = plan

  assert {
    condition     = aws_iam_role.apply.permissions_boundary == aws_iam_policy.apply_boundary.arn
    error_message = "El rol de apply debe llevar la permission boundary del módulo."
  }

  assert {
    condition     = aws_iam_policy.apply_boundary.name == "acme-prod-gha-apply-boundary"
    error_message = "La boundary debe llamarse <project>-<env>-<prefix>-apply-boundary."
  }
}

run "boundary_denies_dangerous_actions" {
  command = plan

  assert {
    condition = alltrue([
      for sid in [
        "DenyTamperingWithOwnRolesAndBoundary",
        "DenyDisablingSecurityServices",
        "DenyHumanAndLongLivedCredentials",
        "DenyStateBucketConfigurationChanges",
        "DenyStateKeyDestruction",
      ] : contains([for s in data.aws_iam_policy_document.apply_boundary.statement : s.sid if s.effect == "Deny"], sid)
    ])
    error_message = "La boundary debe incluir todas las denegaciones exigidas."
  }
}

run "existing_oidc_provider_is_reused" {
  command = plan

  variables {
    create_provider = false
  }

  assert {
    condition     = length(aws_iam_openid_connect_provider.this) == 0 && length(data.aws_iam_openid_connect_provider.existing) == 1
    error_message = "Con create_provider = false se debe reutilizar el proveedor existente."
  }
}

run "oidc_provider_created_by_default" {
  command = plan

  assert {
    condition     = length(aws_iam_openid_connect_provider.this) == 1 && length(data.aws_iam_openid_connect_provider.existing) == 0
    error_message = "Por defecto se crea el proveedor OIDC."
  }
}

run "rejects_wildcards_in_repo" {
  command = plan

  variables {
    github_repo = "acme-*"
  }

  expect_failures = [var.github_repo]
}

run "rejects_wildcards_in_org" {
  command = plan

  variables {
    github_org = "acme*"
  }

  expect_failures = [var.github_org]
}

run "rejects_key_alias_instead_of_arn" {
  command = plan

  variables {
    state_kms_key_arn = "alias/acme-prod-state"
  }

  expect_failures = [var.state_kms_key_arn]
}
