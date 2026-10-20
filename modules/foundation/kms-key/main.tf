data "aws_iam_policy_document" "this" {
  source_policy_documents = var.additional_policy_documents

  # Sin esta declaración la clave quedaría inadministrable; delega en IAM de la cuenta.
  # Es la forma estándar: los permisos reales se acotan con las declaraciones y políticas IAM.
  statement {
    sid       = "EnableAccountRootAndIam"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"] # En una key policy, "*" significa "esta clave"

    principals {
      type        = "AWS"
      identifiers = [local.root_arn]
    }
  }

  dynamic "statement" {
    for_each = length(var.admin_principal_arns) > 0 ? [1] : []

    content {
      sid    = "KeyAdministration"
      effect = "Allow"
      actions = [
        "kms:Create*",
        "kms:Describe*",
        "kms:Enable*",
        "kms:List*",
        "kms:Put*",
        "kms:Update*",
        "kms:Revoke*",
        "kms:Disable*",
        "kms:Get*",
        "kms:Delete*",
        "kms:TagResource",
        "kms:UntagResource",
        "kms:ScheduleKeyDeletion",
        "kms:CancelKeyDeletion",
      ]
      resources = ["*"]

      principals {
        type        = "AWS"
        identifiers = var.admin_principal_arns
      }
    }
  }

  dynamic "statement" {
    for_each = length(var.user_principal_arns) > 0 ? [1] : []

    content {
      sid    = "KeyUsageByPrincipals"
      effect = "Allow"
      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey",
      ]
      resources = ["*"]

      principals {
        type        = "AWS"
        identifiers = var.user_principal_arns
      }
    }
  }

  dynamic "statement" {
    for_each = length(var.service_principals) > 0 ? [1] : []

    content {
      sid    = "KeyUsageByServicePrincipals"
      effect = "Allow"
      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey",
      ]
      resources = ["*"]

      principals {
        type        = "Service"
        identifiers = var.service_principals
      }

      # Evita el confused deputy: el servicio solo actúa en nombre de esta cuenta.
      condition {
        test     = "StringEquals"
        variable = "aws:SourceAccount"
        values   = [local.account_id]
      }
    }
  }

  dynamic "statement" {
    for_each = length(var.via_services) > 0 ? [1] : []

    content {
      sid    = "KeyUsageViaServices"
      effect = "Allow"
      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:CreateGrant",
        "kms:DescribeKey",
      ]
      resources = ["*"]

      principals {
        type        = "AWS"
        identifiers = ["*"] # acotado por las condiciones: solo vía servicio y solo cuenta propia
      }

      condition {
        test     = "StringEquals"
        variable = "kms:ViaService"
        values   = var.via_services
      }

      condition {
        test     = "StringEquals"
        variable = "kms:CallerAccount"
        values   = [local.account_id]
      }
    }
  }
}

resource "aws_kms_key" "this" {
  description             = local.description
  enable_key_rotation     = true
  rotation_period_in_days = 365
  deletion_window_in_days = var.deletion_window_in_days
  multi_region            = var.multi_region
  policy                  = data.aws_iam_policy_document.this.json

  tags = merge(var.tags, { Name = local.name })
}

resource "aws_kms_alias" "this" {
  name          = local.alias_name
  target_key_id = aws_kms_key.this.key_id
}
