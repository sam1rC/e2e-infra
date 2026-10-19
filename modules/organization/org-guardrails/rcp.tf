data "aws_iam_policy_document" "rcp" {
  count = var.enable_resource_control_policies ? 1 : 0

  statement {
    sid       = "EnforceTls"
    effect    = "Deny"
    actions   = ["s3:*", "kms:*", "secretsmanager:*", "sts:*", "sqs:*"]
    resources = ["*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "BoolIfExists"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  # Perímetro de datos: solo principals de la organización o servicios de AWS en su nombre.
  statement {
    sid       = "OnlyOrganizationPrincipals"
    effect    = "Deny"
    actions   = ["s3:*", "kms:*", "secretsmanager:*"]
    resources = ["*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "StringNotEqualsIfExists"
      variable = "aws:PrincipalOrgID"
      values   = [var.organization_id]
    }

    condition {
      test     = "BoolIfExists"
      variable = "aws:PrincipalIsAWSService"
      values   = ["false"]
    }
  }
}

resource "aws_organizations_policy" "rcp" {
  count = var.enable_resource_control_policies ? 1 : 0

  name        = "${local.name}-guardrails-data-perimeter"
  description = "RCP: exige TLS y limita el acceso a S3/KMS/Secrets Manager a la organización."
  type        = "RESOURCE_CONTROL_POLICY"
  content     = data.aws_iam_policy_document.rcp[0].minified_json

  tags = var.tags
}

resource "aws_organizations_policy_attachment" "rcp" {
  for_each = var.enable_resource_control_policies ? toset(var.target_ids) : toset([])

  policy_id = aws_organizations_policy.rcp[0].id
  target_id = each.value
}
