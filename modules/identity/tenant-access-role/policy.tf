data "aws_iam_policy_document" "permissions" {
  # Defensa en profundidad: sin etiqueta de tenant en la sesión no se permite nada (la trust policy ya la exige).
  statement {
    sid       = "DenyWithoutTenantTag"
    effect    = "Deny"
    actions   = ["*"]
    resources = ["*"]

    condition {
      test     = "Null"
      variable = "aws:PrincipalTag/${var.tenant_tag_key}"
      values   = ["true"]
    }
  }

  # --- DynamoDB en modo pool: solo los elementos cuya clave de partición es el tenant de la sesión ---
  dynamic "statement" {
    for_each = var.dynamodb_tables

    content {
      sid       = "TenantItems${local.sid_suffix[statement.key]}"
      effect    = "Allow"
      actions   = statement.value.read_only ? local.dynamodb_read_actions : local.dynamodb_write_actions
      resources = local.dynamodb_resources[statement.key]

      # LeadingKeys compara el valor completo de la clave de partición: debe ser exactamente el tenant (ADR 0006).
      condition {
        test     = "ForAllValues:StringEquals"
        variable = "dynamodb:LeadingKeys"
        values   = [local.tenant_ref]
      }

      # Sin esto, una petición que no aporte LeadingKeys pasaría la condición anterior (verdad vacía).
      condition {
        test     = "Null"
        variable = "dynamodb:LeadingKeys"
        values   = ["false"]
      }
    }
  }

  # Scan y PartiQL leen la tabla entera: se deniegan explícitamente aunque ninguna sentencia los permita.
  dynamic "statement" {
    for_each = length(var.dynamodb_tables) > 0 ? [1] : []

    content {
      sid       = "DenyFullTableReads"
      effect    = "Deny"
      actions   = ["dynamodb:Scan", "dynamodb:PartiQLSelect", "dynamodb:PartiQLInsert", "dynamodb:PartiQLUpdate", "dynamodb:PartiQLDelete"]
      resources = flatten([for t in values(var.dynamodb_tables) : [t.table_arn, "${t.table_arn}/index/*"]])
    }
  }

  # --- S3: objetos bajo <prefix><tenant>/ y listado limitado a ese prefijo ---
  dynamic "statement" {
    for_each = var.s3_buckets

    content {
      sid       = "TenantObjects${local.sid_suffix[statement.key]}"
      effect    = "Allow"
      actions   = statement.value.read_only ? ["s3:GetObject"] : ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
      resources = ["${statement.value.bucket_arn}/${statement.value.prefix}${local.tenant_ref}/*"]
    }
  }

  dynamic "statement" {
    for_each = var.s3_buckets

    content {
      sid       = "TenantPrefixList${local.sid_suffix[statement.key]}"
      effect    = "Allow"
      actions   = ["s3:ListBucket"]
      resources = [statement.value.bucket_arn]

      # Sin s3:prefix la condición no se cumple: listar la raíz del bucket queda denegado.
      condition {
        test     = "StringLike"
        variable = "s3:prefix"
        values   = ["${statement.value.prefix}${local.tenant_ref}/", "${statement.value.prefix}${local.tenant_ref}/*"]
      }
    }
  }

  # La CMK del bucket solo a través de S3 y para ese bucket (con bucket key el contexto es el ARN del bucket).
  dynamic "statement" {
    for_each = { for k, b in var.s3_buckets : k => b if b.kms_key_arn != null }

    content {
      sid       = "BucketKey${local.sid_suffix[statement.key]}"
      effect    = "Allow"
      actions   = statement.value.read_only ? ["kms:Decrypt"] : ["kms:Decrypt", "kms:GenerateDataKey"]
      resources = [statement.value.kms_key_arn]

      condition {
        test     = "StringEquals"
        variable = "kms:ViaService"
        values   = [local.s3_region_service]
      }

      condition {
        test     = "StringEquals"
        variable = "kms:EncryptionContext:aws:s3:arn"
        values   = [statement.value.bucket_arn]
      }
    }
  }

  # --- KMS en la aplicación: solo con el contexto de cifrado del propio tenant ---
  dynamic "statement" {
    for_each = length(var.kms_keys) > 0 ? [1] : []

    content {
      sid       = "TenantEncryptionContext"
      effect    = "Allow"
      actions   = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey", "kms:GenerateDataKeyWithoutPlaintext"]
      resources = sort(values(var.kms_keys))

      condition {
        test     = "StringEquals"
        variable = "kms:EncryptionContext:${var.tenant_tag_key}"
        values   = [local.tenant_ref]
      }
    }
  }
}
