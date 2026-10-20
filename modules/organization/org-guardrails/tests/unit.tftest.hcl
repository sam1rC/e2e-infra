mock_provider "aws" {
  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json          = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
      minified_json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  project         = "acme"
  environment     = "prod"
  target_ids      = ["ou-abcd-12345678", "123456789012"]
  admin_role_arns = ["arn:aws:iam::*:role/AWSControlTowerExecution"]
  allowed_regions = ["us-east-1", "us-west-2"]
}

run "security_policy_has_core_statements" {
  command = plan

  assert {
    condition = toset([for s in data.aws_iam_policy_document.security.statement : s.sid]) == toset([
      "DenyLeaveOrganization", "ProtectSecurityServices", "DenyRootUser",
    ])
    error_message = "Sin estado que proteger, la SCP de seguridad solo lleva las tres declaraciones base."
  }
}

run "state_protection_added_when_state_is_given" {
  command = plan

  variables {
    state_bucket_arns  = ["arn:aws:s3:::acme-prod-tfstate-123456789012"]
    state_kms_key_arns = ["arn:aws:kms:us-east-1:123456789012:key/11111111-2222-3333-4444-555555555555"]
  }

  assert {
    condition = toset([for s in data.aws_iam_policy_document.security.statement : s.sid]) == toset([
      "DenyLeaveOrganization", "ProtectSecurityServices", "DenyRootUser",
      "ProtectStateBucket", "ProtectStateKey", "ProtectCiRoles",
    ])
    error_message = "Con bucket y clave de estado deben añadirse las protecciones de estado y de roles de CI."
  }
}

run "every_deny_except_root_exempts_admin_roles" {
  command = plan

  variables {
    state_bucket_arns = ["arn:aws:s3:::acme-prod-tfstate-123456789012"]
  }

  assert {
    condition = alltrue([
      for s in data.aws_iam_policy_document.security.statement :
      s.effect == "Deny" && (
        s.sid == "DenyRootUser" ||
        anytrue([for c in s.condition : c.test == "ArnNotLike" && c.variable == "aws:PrincipalArn"])
      )
    ])
    error_message = "Todas las denegaciones (salvo root) deben eximir a los roles de administración."
  }
}

run "root_user_denied_without_exemption" {
  command = plan

  assert {
    condition = alltrue([
      for s in data.aws_iam_policy_document.security.statement :
      s.sid != "DenyRootUser" || (
        length(s.condition) == 1 &&
        alltrue([for c in s.condition : c.test == "StringLike" && contains(c.values, "arn:aws:iam::*:root")])
      )
    ])
    error_message = "La denegación de root no admite excepciones."
  }
}

run "security_services_cannot_be_disabled" {
  command = plan

  assert {
    condition = alltrue([
      for a in ["cloudtrail:StopLogging", "guardduty:DeleteDetector", "securityhub:DisableSecurityHub", "config:StopConfigurationRecorder", "access-analyzer:DeleteAnalyzer"] :
      anytrue([for s in data.aws_iam_policy_document.security.statement : contains(s.actions, a)])
    ])
    error_message = "Debe denegarse apagar CloudTrail, GuardDuty, Security Hub, Config y Access Analyzer."
  }
}

run "region_restriction_uses_allowed_regions_and_global_exemptions" {
  command = plan

  assert {
    condition = alltrue([
      for s in data.aws_iam_policy_document.region.statement :
      s.effect == "Deny" &&
      contains(s.not_actions, "iam:*") && contains(s.not_actions, "cloudfront:*") && contains(s.not_actions, "sts:*") &&
      anytrue([for c in s.condition : c.variable == "aws:RequestedRegion" && c.test == "StringNotEquals" && toset(c.values) == toset(["us-east-1", "us-west-2"])])
    ])
    error_message = "La restricción de región debe usar allowed_regions y eximir servicios globales."
  }
}

run "policies_are_service_control_policies" {
  command = plan

  assert {
    condition     = aws_organizations_policy.security.type == "SERVICE_CONTROL_POLICY" && aws_organizations_policy.region.type == "SERVICE_CONTROL_POLICY"
    error_message = "Las dos políticas base deben ser SCP."
  }
}

run "attachments_are_keyed_by_target_and_policy" {
  command = plan

  assert {
    condition = toset(keys(aws_organizations_policy_attachment.this)) == toset([
      "ou-abcd-12345678/security", "ou-abcd-12345678/region",
      "123456789012/security", "123456789012/region",
    ])
    error_message = "Cada destino recibe las dos SCP con claves estables <target>/<policy>."
  }
}

run "removing_a_target_keeps_other_attachments_stable" {
  command = plan

  variables {
    target_ids = ["123456789012"]
  }

  assert {
    condition     = toset(keys(aws_organizations_policy_attachment.this)) == toset(["123456789012/security", "123456789012/region"])
    error_message = "Quitar un destino no debe tocar los demás."
  }
}

run "rcp_disabled_by_default" {
  command = plan

  assert {
    condition     = length(aws_organizations_policy.rcp) == 0 && length(aws_organizations_policy_attachment.rcp) == 0
    error_message = "La RCP debe estar desactivada por defecto."
  }
}

run "rcp_created_when_enabled" {
  command = plan

  variables {
    enable_resource_control_policies = true
    organization_id                  = "o-abcde12345"
  }

  assert {
    condition     = length(aws_organizations_policy.rcp) == 1 && aws_organizations_policy.rcp[0].type == "RESOURCE_CONTROL_POLICY" && length(aws_organizations_policy_attachment.rcp) == 2
    error_message = "La RCP debe crearse y adjuntarse a cada destino."
  }
}

run "rejects_rcp_without_organization_id" {
  command = plan

  variables {
    enable_resource_control_policies = true
  }

  expect_failures = [var.organization_id]
}

run "rejects_empty_admin_roles" {
  command = plan

  variables {
    admin_role_arns = []
  }

  expect_failures = [var.admin_role_arns]
}

run "rejects_invalid_target_id" {
  command = plan

  variables {
    target_ids = ["not-an-id"]
  }

  expect_failures = [var.target_ids]
}

run "rejects_invalid_region" {
  command = plan

  variables {
    allowed_regions = ["useast1"]
  }

  expect_failures = [var.allowed_regions]
}
