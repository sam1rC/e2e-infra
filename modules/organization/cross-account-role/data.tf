data "aws_iam_policy_document" "trust" {
  statement {
    sid     = "AssumeFromTrustedRoles"
    effect  = "Allow"
    actions = var.allow_tag_session ? ["sts:AssumeRole", "sts:TagSession"] : ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = var.trusted_role_arns
    }

    # Confused deputy: un tercero solo puede asumir el rol pasando el ExternalId acordado con el cliente.
    dynamic "condition" {
      for_each = var.external_id == null ? [] : [var.external_id]

      content {
        test     = "StringEquals"
        variable = "sts:ExternalId"
        values   = [condition.value]
      }
    }

    dynamic "condition" {
      for_each = var.organization_id == null ? [] : [var.organization_id]

      content {
        test     = "StringEquals"
        variable = "aws:PrincipalOrgID"
        values   = [condition.value]
      }
    }

    dynamic "condition" {
      for_each = var.require_mfa ? [1] : []

      content {
        test     = "Bool"
        variable = "aws:MultiFactorAuthPresent"
        values   = ["true"]
      }
    }
  }
}
