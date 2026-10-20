data "aws_iam_policy_document" "security" {
  statement {
    sid       = "DenyLeaveOrganization"
    effect    = "Deny"
    actions   = ["organizations:LeaveOrganization"]
    resources = ["*"]

    condition {
      test     = "ArnNotLike"
      variable = "aws:PrincipalArn"
      values   = var.admin_role_arns
    }
  }

  # UpdateDetector no admite condicionar por Enable=false en una SCP: se deniega por completo
  # y los cambios de configuración de GuardDuty/CloudTrail los hace un rol exento.
  statement {
    sid    = "ProtectSecurityServices"
    effect = "Deny"
    actions = [
      "cloudtrail:StopLogging",
      "cloudtrail:DeleteTrail",
      "cloudtrail:UpdateTrail",
      "guardduty:DeleteDetector",
      "guardduty:DisassociateFromMasterAccount",
      "guardduty:UpdateDetector",
      "securityhub:DisableSecurityHub",
      "config:StopConfigurationRecorder",
      "config:DeleteConfigurationRecorder",
      "access-analyzer:DeleteAnalyzer",
    ]
    resources = ["*"]

    condition {
      test     = "ArnNotLike"
      variable = "aws:PrincipalArn"
      values   = var.admin_role_arns
    }
  }

  statement {
    sid       = "DenyRootUser"
    effect    = "Deny"
    actions   = ["*"]
    resources = ["*"]

    condition {
      test     = "StringLike"
      variable = "aws:PrincipalArn"
      values   = ["arn:${local.partition}:iam::*:root"]
    }
  }

  dynamic "statement" {
    for_each = length(var.state_bucket_arns) > 0 ? [1] : []

    content {
      sid    = "ProtectStateBucket"
      effect = "Deny"
      actions = [
        "s3:DeleteBucket",
        "s3:PutBucketPolicy",
        "s3:DeleteBucketPolicy",
        "s3:PutBucketVersioning",
        "s3:PutEncryptionConfiguration",
        "s3:PutBucketPublicAccessBlock",
        "s3:DeleteObjectVersion",
      ]
      resources = concat(var.state_bucket_arns, [for a in var.state_bucket_arns : "${a}/*"])

      condition {
        test     = "ArnNotLike"
        variable = "aws:PrincipalArn"
        values   = local.bootstrap_arns
      }
    }
  }

  dynamic "statement" {
    for_each = length(var.state_kms_key_arns) > 0 ? [1] : []

    content {
      sid    = "ProtectStateKey"
      effect = "Deny"
      actions = [
        "kms:ScheduleKeyDeletion",
        "kms:DisableKey",
        "kms:DisableKeyRotation",
        "kms:PutKeyPolicy",
      ]
      resources = var.state_kms_key_arns

      condition {
        test     = "ArnNotLike"
        variable = "aws:PrincipalArn"
        values   = local.bootstrap_arns
      }
    }
  }

  dynamic "statement" {
    for_each = local.protect_state ? [1] : []

    content {
      sid    = "ProtectCiRoles"
      effect = "Deny"
      actions = [
        "iam:DeleteRole",
        "iam:UpdateAssumeRolePolicy",
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:PutRolePermissionsBoundary",
        "iam:DeleteRolePermissionsBoundary",
      ]
      resources = [
        "arn:${local.partition}:iam::*:role/${var.ci_role_name_prefix}-plan-*",
        "arn:${local.partition}:iam::*:role/${var.ci_role_name_prefix}-apply-*",
      ]

      condition {
        test     = "ArnNotLike"
        variable = "aws:PrincipalArn"
        values   = local.bootstrap_arns
      }
    }
  }
}

data "aws_iam_policy_document" "region" {
  statement {
    sid         = "RegionRestriction"
    effect      = "Deny"
    not_actions = var.global_service_actions
    resources   = ["*"]

    condition {
      test     = "StringNotEquals"
      variable = "aws:RequestedRegion"
      values   = var.allowed_regions
    }

    condition {
      test     = "ArnNotLike"
      variable = "aws:PrincipalArn"
      values   = var.admin_role_arns
    }
  }
}

resource "aws_organizations_policy" "security" {
  name        = "${local.name}-guardrails-security"
  description = "Protege los servicios de seguridad, el estado de OpenTofu y los roles de CI; deniega root y salir de la organización."
  type        = "SERVICE_CONTROL_POLICY"
  content     = data.aws_iam_policy_document.security.minified_json

  tags = var.tags

  lifecycle {
    precondition {
      condition     = length(data.aws_iam_policy_document.security.minified_json) <= local.policy_max_chars
      error_message = "La SCP de seguridad supera los 5120 caracteres: reduce admin_role_arns/state_*_arns o usa comodines."
    }
  }
}

resource "aws_organizations_policy" "region" {
  name        = "${local.name}-guardrails-region"
  description = "Deniega la actividad fuera de las regiones permitidas, salvo servicios globales."
  type        = "SERVICE_CONTROL_POLICY"
  content     = data.aws_iam_policy_document.region.minified_json

  tags = var.tags

  lifecycle {
    precondition {
      condition     = length(data.aws_iam_policy_document.region.minified_json) <= local.policy_max_chars
      error_message = "La SCP de regiones supera los 5120 caracteres: reduce global_service_actions o admin_role_arns."
    }
  }
}

resource "aws_organizations_policy_attachment" "this" {
  for_each = local.attachments

  policy_id = each.value.policy == "security" ? aws_organizations_policy.security.id : aws_organizations_policy.region.id
  target_id = each.value.target_id
}
