# Rol asumible desde otras cuentas: despliegue en cuentas silo desde el control plane o el CI (SaaS T1) y
# acceso del proveedor revocable (runbook revoke-provider-access). Solo roles concretos en la confianza.
resource "aws_iam_role" "this" {
  name                 = local.name
  description          = "Rol entre cuentas ${local.name} (confianza en roles concretos)"
  assume_role_policy   = data.aws_iam_policy_document.trust.json
  max_session_duration = var.max_session_duration
  permissions_boundary = var.permissions_boundary_arn

  tags = merge(var.tags, { Name = local.name })
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each = var.managed_policy_arns

  role       = aws_iam_role.this.name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "inline" {
  for_each = var.inline_policies

  name   = each.key
  role   = aws_iam_role.this.id
  policy = each.value
}
