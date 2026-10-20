# Token vending machine: la aplicación asume este rol por petición pasando como etiqueta de sesión el tenant
# que leyó del JWT validado; todas las condiciones de los permisos dependen de esa etiqueta.
data "aws_iam_policy_document" "trust" {
  statement {
    sid     = "AppAssumesWithTenantTag"
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "AWS"
      identifiers = var.trusted_role_arns
    }

    # La etiqueta del tenant es obligatoria y no vacía.
    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/${var.tenant_tag_key}"
      values   = ["?*"]
    }

    # Solo esa etiqueta: la aplicación no puede añadir otras que alguna política pudiera evaluar.
    condition {
      test     = "ForAllValues:StringEquals"
      variable = "aws:TagKeys"
      values   = [var.tenant_tag_key]
    }

    # ForAllValues es verdadero si la clave no existe (verdad vacía): se exige que exista.
    condition {
      test     = "Null"
      variable = "aws:TagKeys"
      values   = ["false"]
    }
  }
}

resource "aws_iam_role" "this" {
  name                 = local.role_name
  description          = "Acceso a datos de un tenant con etiqueta de sesion (ABAC); lo asume la aplicacion por peticion"
  assume_role_policy   = data.aws_iam_policy_document.trust.json
  permissions_boundary = var.permissions_boundary_arn

  # La aplicación asume este rol desde su propio rol (encadenamiento): AWS limita esas sesiones a 1 hora.
  max_session_duration = 3600

  tags = merge(var.tags, { Name = local.role_name, TenantIsolation = "session-tag" })
}

resource "aws_iam_role_policy" "tenant_data" {
  name   = "tenant-data"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.permissions.json
}
