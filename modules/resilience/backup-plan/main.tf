resource "aws_backup_vault" "this" {
  name        = local.vault_name
  kms_key_arn = var.kms_key_arn

  tags = merge(var.tags, { Name = local.vault_name })
}

# Modo compliance (changeable_for_days >= 3): tras el enfriamiento el bloqueo es irreversible.
resource "aws_backup_vault_lock_configuration" "this" {
  count = var.vault_lock == null ? 0 : 1

  backup_vault_name   = aws_backup_vault.this.name
  min_retention_days  = var.vault_lock.min_retention_days
  max_retention_days  = var.vault_lock.max_retention_days
  changeable_for_days = var.vault_lock.changeable_for_days
}

data "aws_iam_policy_document" "vault" {
  count = length(var.allow_copy_from_account_ids) > 0 ? 1 : 0

  statement {
    sid       = "AllowCopyIntoVaultFromListedAccounts"
    effect    = "Allow"
    actions   = ["backup:CopyIntoBackupVault"]
    resources = ["*"] # En una política de vault, "*" es el propio vault.

    principals {
      type        = "AWS"
      identifiers = [for a in var.allow_copy_from_account_ids : "arn:${data.aws_partition.current.partition}:iam::${a}:root"]
    }
  }
}

resource "aws_backup_vault_policy" "this" {
  count = length(var.allow_copy_from_account_ids) > 0 ? 1 : 0

  backup_vault_name = aws_backup_vault.this.name
  policy            = data.aws_iam_policy_document.vault[0].json
}

resource "aws_backup_plan" "this" {
  count = var.plan_enabled ? 1 : 0

  name = local.vault_name

  rule {
    rule_name                    = "daily"
    target_vault_name            = aws_backup_vault.this.name
    schedule                     = var.schedule.daily_cron
    schedule_expression_timezone = "UTC"
    start_window                 = 60
    completion_window            = 480

    lifecycle {
      delete_after = var.schedule.daily_retention_days
    }

    dynamic "copy_action" {
      for_each = var.copy_destinations

      content {
        destination_vault_arn = copy_action.value.vault_arn

        lifecycle {
          delete_after = coalesce(copy_action.value.retention_days, var.schedule.daily_retention_days)
        }
      }
    }
  }

  rule {
    rule_name                    = "monthly"
    target_vault_name            = aws_backup_vault.this.name
    schedule                     = var.schedule.monthly_cron
    schedule_expression_timezone = "UTC"
    start_window                 = 60
    completion_window            = 480

    lifecycle {
      cold_storage_after = local.cold_storage_days
      delete_after       = var.schedule.monthly_retention_days
    }

    dynamic "copy_action" {
      for_each = var.copy_destinations

      content {
        destination_vault_arn = copy_action.value.vault_arn

        lifecycle {
          delete_after = coalesce(copy_action.value.retention_days, var.schedule.monthly_retention_days)
        }
      }
    }
  }

  # Las copias a otros vaults solo se declaran en las reglas diaria y mensual (la continua no las admite).
  # Backup continuo (PITR gestionado por AWS Backup): lo admiten Aurora, RDS y S3; para el resto
  # de recursos seleccionados la regla no genera copias.
  dynamic "rule" {
    for_each = local.continuous_enabled ? [1] : []

    content {
      rule_name                = "continuous"
      target_vault_name        = aws_backup_vault.this.name
      schedule                 = var.schedule.daily_cron
      enable_continuous_backup = true
      start_window             = 60
      completion_window        = 480

      lifecycle {
        delete_after = var.schedule.continuous_retention_days
      }
    }
  }

  tags = merge(var.tags, { Name = local.vault_name })
}

resource "aws_backup_selection" "by_tag" {
  count = var.plan_enabled ? 1 : 0

  name         = "${local.vault_name}-by-tag"
  plan_id      = aws_backup_plan.this[0].id
  iam_role_arn = aws_iam_role.backup[0].arn

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "BackupPlan"
    value = var.tier
  }
}
