# Cuenta miembro de AWS Organizations (SaaS T1: security, log-archive, control-plane, app-* y silo-<tenant>).
# Se aplica desde la cuenta de management. Las SCP llegan por la OU (organization/org-guardrails).
resource "aws_organizations_account" "this" {
  name                       = local.name
  email                      = var.email
  parent_id                  = var.parent_id
  role_name                  = var.role_name
  iam_user_access_to_billing = var.iam_user_access_to_billing
  close_on_deletion          = var.close_on_deletion

  # Environment explícito: la composición de la cuenta de management etiqueta por defecto su propio entorno.
  tags = merge(var.tags, { Name = local.name, AccountKey = var.account_key, Environment = var.environment })

  lifecycle {
    # Organizations no devuelve role_name ni el acceso a facturación tras crear la cuenta: sin esto, cada
    # plan propondría recrearla (lo que la cerraría o la sacaría de la organización).
    ignore_changes = [role_name, iam_user_access_to_billing]
  }
}
