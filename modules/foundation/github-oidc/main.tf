resource "aws_iam_openid_connect_provider" "this" {
  count = var.create_provider ? 1 : 0

  url            = "https://${local.oidc_host}"
  client_id_list = ["sts.amazonaws.com"]

  tags = var.tags
}

# --- Trust policies -------------------------------------------------------------------------

data "aws_iam_policy_document" "plan_trust" {
  statement {
    sid     = "GitHubActionsPlan"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = local.plan_subjects
    }
  }
}

data "aws_iam_policy_document" "apply_trust" {
  statement {
    sid     = "GitHubActionsApply"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Solo el job que despliega al GitHub Environment (con aprobación en prod) puede asumirlo:
    # ninguna rama ni pull request, aunque modifique el workflow, obtiene este rol.
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = local.apply_subjects
    }
  }
}

# --- Acceso al estado (común a plan y apply) -------------------------------------------------

data "aws_iam_policy_document" "state_access" {
  statement {
    sid       = "ListStatePrefix"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [var.state_bucket_arn]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["${local.state_prefix}*"]
    }
  }

  # DeleteObject es necesario para liberar el lock nativo (use_lockfile); en un bucket versionado
  # solo crea un delete marker y no destruye versiones del estado.
  statement {
    sid       = "ReadWriteStateObjects"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${var.state_bucket_arn}/${local.state_prefix}*"]
  }

  statement {
    sid       = "UseStateKey"
    effect    = "Allow"
    actions   = ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
    resources = [var.state_kms_key_arn]
  }
}

resource "aws_iam_policy" "state_access" {
  name        = "${var.project}-${var.environment}-${var.name_prefix}-state-access"
  description = "Lectura/escritura del prefijo de estado ${local.state_prefix} y uso de su CMK."
  policy      = data.aws_iam_policy_document.state_access.json

  tags = var.tags
}

# --- Rol de plan ------------------------------------------------------------------------------

resource "aws_iam_role" "plan" {
  name                 = local.plan_role_name
  description          = "GitHub Actions: tofu plan de ${var.environment} (solo lectura + estado)"
  assume_role_policy   = data.aws_iam_policy_document.plan_trust.json
  max_session_duration = 3600

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "plan_managed" {
  for_each = toset(var.plan_policy_arns)

  role       = aws_iam_role.plan.name
  policy_arn = each.value
}

resource "aws_iam_role_policy_attachment" "plan_state" {
  role       = aws_iam_role.plan.name
  policy_arn = aws_iam_policy.state_access.arn
}

# ReadOnlyAccess no incluye kms:Decrypt: Lambda devuelve sus variables de entorno vacías al rol de plan cuando están
# cifradas con una CMK, y cada plan (y el detector de drift) vería un cambio falso. Solo a través de Lambda y solo
# claves de esta cuenta; las variables de entorno nunca llevan secretos (regla 0.1). E2E de la fase 12, 2026-10-19.
data "aws_iam_policy_document" "plan_read_encrypted_config" {
  statement {
    sid       = "ReadLambdaEnvironmentViaLambda"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = ["arn:${local.partition}:kms:*:${local.account_id}:key/*"]

    condition {
      test     = "StringLike"
      variable = "kms:ViaService"
      values   = ["lambda.*.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "plan_read_encrypted_config" {
  name   = "read-encrypted-config"
  role   = aws_iam_role.plan.id
  policy = data.aws_iam_policy_document.plan_read_encrypted_config.json
}

# --- Permission boundary del rol de apply ----------------------------------------------------

data "aws_iam_policy_document" "apply_boundary" {
  statement {
    sid       = "AllowEverythingElse"
    effect    = "Allow"
    actions   = ["*"]
    resources = ["*"] # Es un techo: lo que no se deniega abajo queda limitado por las políticas de identidad
  }

  statement {
    sid    = "DenyTamperingWithOwnRolesAndBoundary"
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
      "iam:UpdateRole",
      "iam:UpdateRoleDescription",
    ]
    resources = [local.plan_role_arn, local.apply_role_arn]
  }

  statement {
    sid    = "DenyTamperingWithBoundaryPolicyAndOidcProvider"
    effect = "Deny"
    actions = [
      "iam:DeletePolicy",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion",
      "iam:SetDefaultPolicyVersion",
    ]
    resources = [local.boundary_policy_arn, aws_iam_policy.state_access.arn]
  }

  statement {
    sid    = "DenyOidcProviderChanges"
    effect = "Deny"
    actions = [
      "iam:DeleteOpenIDConnectProvider",
      "iam:UpdateOpenIDConnectProviderThumbprint",
      "iam:AddClientIDToOpenIDConnectProvider",
      "iam:RemoveClientIDFromOpenIDConnectProvider",
    ]
    resources = [local.provider_arn]
  }

  statement {
    sid    = "DenyDisablingSecurityServices"
    effect = "Deny"
    actions = [
      "cloudtrail:StopLogging",
      "cloudtrail:DeleteTrail",
      "guardduty:DeleteDetector",
      "guardduty:DisassociateFromAdministratorAccount",
      "guardduty:DisassociateFromMasterAccount",
      "securityhub:DisableSecurityHub",
      "securityhub:DisassociateFromAdministratorAccount",
      "config:StopConfigurationRecorder",
      "config:DeleteConfigurationRecorder",
      "access-analyzer:DeleteAnalyzer",
    ]
    resources = ["*"] # Estas APIs no admiten restricción por recurso útil: el bloqueo es a nivel de cuenta
  }

  statement {
    sid    = "DenyHumanAndLongLivedCredentials"
    effect = "Deny"
    actions = [
      "iam:CreateUser",
      "iam:CreateAccessKey",
      "iam:CreateLoginProfile",
      "iam:UpdateLoginProfile",
      "iam:CreateServiceSpecificCredential",
    ]
    resources = ["*"] # Sin recurso conocido de antemano: se prohíbe en toda la cuenta
  }

  statement {
    sid    = "DenyStateBucketConfigurationChanges"
    effect = "Deny"
    actions = [
      "s3:DeleteBucket",
      "s3:PutBucketPolicy",
      "s3:DeleteBucketPolicy",
      "s3:PutBucketVersioning",
      "s3:PutEncryptionConfiguration",
      "s3:PutBucketPublicAccessBlock",
      "s3:PutLifecycleConfiguration",
      "s3:PutBucketObjectLockConfiguration",
      "s3:DeleteObjectVersion",
    ]
    resources = [var.state_bucket_arn, "${var.state_bucket_arn}/*"]
  }

  statement {
    sid    = "DenyStateKeyDestruction"
    effect = "Deny"
    actions = [
      "kms:ScheduleKeyDeletion",
      "kms:DisableKey",
      "kms:DisableKeyRotation",
      "kms:PutKeyPolicy",
    ]
    resources = [var.state_kms_key_arn]
  }
}

resource "aws_iam_policy" "apply_boundary" {
  name        = local.boundary_policy_name
  description = "Permission boundary del rol de apply de ${var.environment}: techo de permisos y protección de la propia identidad de CI."
  policy      = data.aws_iam_policy_document.apply_boundary.json

  tags = var.tags
}

# --- Rol de apply -----------------------------------------------------------------------------

resource "aws_iam_role" "apply" {
  name                 = local.apply_role_name
  description          = "GitHub Actions: tofu apply de ${var.environment} (solo desde el GitHub Environment ${local.github_environment})"
  assume_role_policy   = data.aws_iam_policy_document.apply_trust.json
  permissions_boundary = aws_iam_policy.apply_boundary.arn
  max_session_duration = 3600

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "apply_managed" {
  for_each = toset(var.apply_policy_arns)

  role       = aws_iam_role.apply.name
  policy_arn = each.value
}

resource "aws_iam_role_policy_attachment" "apply_state" {
  role       = aws_iam_role.apply.name
  policy_arn = aws_iam_policy.state_access.arn
}
