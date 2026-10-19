data "aws_iam_policy_document" "assume" {
  statement {
    sid     = "BackupAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }

    # Evita el confused deputy: solo AWS Backup actuando en esta cuenta.
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

# El plan pide expresamente las políticas gestionadas de AWS Backup: cubren el catálogo de servicios que
# AWS Backup soporta y AWS las mantiene al día con cada servicio nuevo.
resource "aws_iam_role" "backup" {
  count = var.plan_enabled ? 1 : 0

  name_prefix        = "${local.vault_name}-"
  description        = "Rol de servicio de AWS Backup para ${local.vault_name}"
  assume_role_policy = data.aws_iam_policy_document.assume.json

  tags = merge(var.tags, { Name = "${local.vault_name}-backup" })
}

resource "aws_iam_role_policy_attachment" "backup" {
  count = var.plan_enabled ? 1 : 0

  role       = aws_iam_role.backup[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "restores" {
  count = var.plan_enabled ? 1 : 0

  role       = aws_iam_role.backup[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}
