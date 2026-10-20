mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }

  # Un JSON válido: aws_iam_role y aws_backup_vault_policy rechazan el texto aleatorio que genera el mock.
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/acme-dev-backup"
    }
  }

  mock_resource "aws_backup_vault" {
    defaults = {
      arn = "arn:aws:backup:us-east-1:123456789012:backup-vault:acme-dev-backup"
    }
  }
}

variables {
  project     = "acme"
  environment = "dev"
  kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/11111111-2222-3333-4444-555555555555"
  tier        = "growth"
}

run "vault_is_encrypted_with_its_own_cmk" {
  command = plan

  assert {
    condition = (
      aws_backup_vault.this.name == "acme-dev-backup" &&
      aws_backup_vault.this.kms_key_arn == var.kms_key_arn
    )
    error_message = "El vault debe llamarse <project>-<env>-<name> y cifrarse con la CMK indicada."
  }
}

run "plan_has_daily_monthly_and_continuous_rules" {
  command = plan

  assert {
    condition     = toset([for r in aws_backup_plan.this[0].rule : r.rule_name]) == toset(["daily", "monthly", "continuous"])
    error_message = "El plan debe tener las reglas diaria, mensual y continua."
  }

  assert {
    condition = (
      alltrue([for r in aws_backup_plan.this[0].rule : alltrue([for l in r.lifecycle : l.delete_after == 35]) if r.rule_name == "daily"]) &&
      alltrue([for r in aws_backup_plan.this[0].rule : alltrue([for l in r.lifecycle : l.delete_after == 365 && l.cold_storage_after == 30]) if r.rule_name == "monthly"]) &&
      alltrue([for r in aws_backup_plan.this[0].rule : r.enable_continuous_backup == true && alltrue([for l in r.lifecycle : l.delete_after == 35]) if r.rule_name == "continuous"])
    )
    error_message = "Diaria 35 días, mensual 365 días con frío a los 30, y continua 35 días."
  }

  assert {
    condition     = length(aws_backup_plan.this[0].rule) == 3 && alltrue([for r in aws_backup_plan.this[0].rule : r.target_vault_name == "acme-dev-backup"])
    error_message = "Todas las reglas deben escribir en el vault del módulo."
  }
}

run "continuous_rule_can_be_disabled" {
  command = plan

  variables {
    schedule = { continuous_retention_days = 0 }
  }

  assert {
    condition     = toset([for r in aws_backup_plan.this[0].rule : r.rule_name]) == toset(["daily", "monthly"])
    error_message = "continuous_retention_days = 0 debe quitar la regla continua."
  }
}

run "cold_storage_can_be_disabled" {
  command = plan

  variables {
    schedule = { monthly_cold_storage_after_days = 0 }
  }

  assert {
    condition     = alltrue([for r in aws_backup_plan.this[0].rule : alltrue([for l in r.lifecycle : l.cold_storage_after == null || l.cold_storage_after == 0]) if r.rule_name == "monthly"])
    error_message = "monthly_cold_storage_after_days = 0 no debe pasar a almacenamiento frío."
  }
}

run "selection_is_by_backup_plan_tag" {
  command = plan

  assert {
    condition = (
      length(aws_backup_selection.by_tag) == 1 &&
      alltrue([for t in aws_backup_selection.by_tag[0].selection_tag : t.type == "STRINGEQUALS" && t.key == "BackupPlan" && t.value == "growth"])
    )
    error_message = "La selección debe ser por la etiqueta BackupPlan = <tier>."
  }

  assert {
    condition     = length(aws_backup_selection.by_tag[0].selection_tag) == 1
    error_message = "Solo debe haber una etiqueta de selección."
  }
}

run "service_role_uses_the_two_aws_managed_backup_policies" {
  command = plan

  assert {
    condition = (
      aws_iam_role_policy_attachment.backup[0].policy_arn == "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup" &&
      aws_iam_role_policy_attachment.restores[0].policy_arn == "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
    )
    error_message = "El rol debe llevar AWSBackupServiceRolePolicyForBackup y ...ForRestores."
  }

  assert {
    condition = (
      length(data.aws_iam_policy_document.assume.statement) == 1 &&
      alltrue([
        for s in data.aws_iam_policy_document.assume.statement :
        anytrue([for c in s.condition : c.variable == "aws:SourceAccount" && toset(c.values) == toset(["123456789012"])])
      ])
    )
    error_message = "El trust del rol debe limitarse a AWS Backup en esta cuenta."
  }
}

run "copy_actions_target_destination_vaults_on_daily_and_monthly_only" {
  command = plan

  variables {
    copy_destinations = {
      dr = { vault_arn = "arn:aws:backup:us-west-2:123456789012:backup-vault:acme-dev-dr" }
      org = {
        vault_arn      = "arn:aws:backup:us-east-1:210987654321:backup-vault:org-backup"
        retention_days = 90
      }
    }
  }

  assert {
    condition = alltrue([
      for r in aws_backup_plan.this[0].rule :
      toset([for c in r.copy_action : c.destination_vault_arn]) == toset([
        "arn:aws:backup:us-west-2:123456789012:backup-vault:acme-dev-dr",
        "arn:aws:backup:us-east-1:210987654321:backup-vault:org-backup",
      ]) if r.rule_name != "continuous"
    ]) && alltrue([for r in aws_backup_plan.this[0].rule : length(r.copy_action) == 0 if r.rule_name == "continuous"])
    error_message = "La diaria y la mensual deben copiar a todos los destinos; la continua, a ninguno."
  }

  assert {
    condition = anytrue(flatten([
      for r in aws_backup_plan.this[0].rule : [
        for c in r.copy_action : alltrue([for l in c.lifecycle : l.delete_after == 90]) if c.destination_vault_arn == "arn:aws:backup:us-east-1:210987654321:backup-vault:org-backup"
      ] if r.rule_name == "daily"
    ]))
    error_message = "retention_days del destino debe sustituir a la retención de la regla."
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.copy_jobs_failed) == 1
    error_message = "Con copias debe existir la alarma de copias fallidas."
  }
}

run "without_copies_there_is_no_copy_alarm" {
  command = plan

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.copy_jobs_failed) == 0 && length(aws_cloudwatch_metric_alarm.backup_jobs_failed) == 1
    error_message = "Sin copias solo debe existir la alarma de backups fallidos."
  }
}

run "failed_job_alarms_notify_the_given_topics" {
  command = plan

  variables {
    alarm_actions = ["arn:aws:sns:us-east-1:123456789012:acme-dev-alarms"]
  }

  assert {
    condition = (
      aws_cloudwatch_metric_alarm.backup_jobs_failed[0].metric_name == "NumberOfBackupJobsFailed" &&
      aws_cloudwatch_metric_alarm.backup_jobs_failed[0].namespace == "AWS/Backup" &&
      aws_cloudwatch_metric_alarm.backup_jobs_failed[0].treat_missing_data == "notBreaching" &&
      contains(aws_cloudwatch_metric_alarm.backup_jobs_failed[0].alarm_actions, "arn:aws:sns:us-east-1:123456789012:acme-dev-alarms")
    )
    error_message = "La alarma de backups fallidos debe notificar al topic indicado y no saltar sin datos."
  }
}

run "vault_only_mode_creates_no_plan_role_or_alarms" {
  command = plan

  variables {
    plan_enabled = false
    tier         = null
    name         = "dr"
  }

  assert {
    condition = (
      aws_backup_vault.this.name == "acme-dev-dr" &&
      length(aws_backup_plan.this) == 0 &&
      length(aws_backup_selection.by_tag) == 0 &&
      length(aws_iam_role.backup) == 0 &&
      length(aws_cloudwatch_metric_alarm.backup_jobs_failed) == 0
    )
    error_message = "Con plan_enabled = false solo debe crearse el vault."
  }
}

run "vault_lock_is_compliance_mode_with_cooling_off" {
  command = plan

  variables {
    vault_lock = { min_retention_days = 7, changeable_for_days = 3 }
  }

  assert {
    condition = (
      length(aws_backup_vault_lock_configuration.this) == 1 &&
      aws_backup_vault_lock_configuration.this[0].min_retention_days == 7 &&
      aws_backup_vault_lock_configuration.this[0].changeable_for_days == 3
    )
    error_message = "El bloqueo debe ser en modo compliance (changeable_for_days = 3) con mínimo de 7 días."
  }
}

run "no_vault_lock_by_default_outside_prod" {
  command = plan

  assert {
    condition     = length(aws_backup_vault_lock_configuration.this) == 0
    error_message = "Fuera de prod el bloqueo es opcional."
  }
}

run "listed_accounts_can_copy_into_the_vault" {
  command = plan

  variables {
    plan_enabled                = false
    tier                        = null
    name                        = "central"
    allow_copy_from_account_ids = ["210987654321"]
  }

  assert {
    condition = (
      length(aws_backup_vault_policy.this) == 1 &&
      alltrue([for s in data.aws_iam_policy_document.vault[0].statement : toset(s.actions) == toset(["backup:CopyIntoBackupVault"])])
    )
    error_message = "La política del vault de destino solo debe permitir backup:CopyIntoBackupVault a las cuentas indicadas."
  }
}

run "restore_testing_creates_a_plan_and_one_selection_per_type_scoped_by_tag" {
  command = plan

  variables {
    restore_testing = {
      resource_types = ["Aurora", "DynamoDB"]
      metadata_overrides = {
        Aurora = { dbsubnetgroupname = "acme-dev-aurora" }
      }
    }
  }

  assert {
    condition = (
      aws_backup_restore_testing_plan.this[0].name == "acme_dev_backup_restore" &&
      aws_backup_restore_testing_plan.this[0].schedule_expression == "cron(0 6 1 * ? *)" &&
      toset(keys(aws_backup_restore_testing_selection.this)) == toset(["Aurora", "DynamoDB"])
    )
    error_message = "Debe haber un plan de pruebas mensual (nombre sin guiones) y una selección por tipo."
  }

  assert {
    condition = (
      aws_backup_restore_testing_selection.this["Aurora"].name == "acme_dev_backup_aurora" &&
      aws_backup_restore_testing_selection.this["Aurora"].restore_metadata_overrides["dbsubnetgroupname"] == "acme-dev-aurora" &&
      length(aws_backup_restore_testing_selection.this["DynamoDB"].restore_metadata_overrides) == 0
    )
    error_message = "Los overrides de restauración deben aplicarse solo al tipo indicado."
  }

  assert {
    condition = alltrue([
      for s in aws_backup_restore_testing_selection.this :
      alltrue([for c in s.protected_resource_conditions : alltrue([for e in c.string_equals : e.key == "aws:ResourceTag/BackupPlan" && e.value == "growth"])])
      ]) && alltrue([
      for p in aws_backup_restore_testing_plan.this[0].recovery_point_selection :
      p.algorithm == "LATEST_WITHIN_WINDOW" && toset(p.recovery_point_types) == toset(["CONTINUOUS", "SNAPSHOT"])
    ])
    error_message = "Las pruebas deben limitarse a los recursos del tier y restaurar el último recovery point."
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.restore_jobs_failed) == 1
    error_message = "Con pruebas de restauración debe existir la alarma de restauraciones fallidas."
  }
}

run "no_restore_testing_by_default" {
  command = plan

  assert {
    condition     = length(aws_backup_restore_testing_plan.this) == 0 && length(aws_backup_restore_testing_selection.this) == 0 && length(aws_cloudwatch_metric_alarm.restore_jobs_failed) == 0
    error_message = "Las pruebas de restauración son opcionales."
  }
}

run "ssm_parameters_are_published_under_resilience_layer" {
  command = apply

  assert {
    condition = (
      toset(keys(aws_ssm_parameter.this)) == toset(["backup_vault_name", "backup_vault_arn"]) &&
      aws_ssm_parameter.this["backup_vault_arn"].name == "/acme/dev/resilience/backup_vault_arn" &&
      alltrue([for p in aws_ssm_parameter.this : p.type == "String"])
    )
    error_message = "Deben publicarse nombre y ARN bajo /<project>/<env>/resilience/."
  }
}

run "ssm_publication_can_be_disabled" {
  command = plan

  variables {
    publish_ssm_parameters = false
  }

  assert {
    condition     = length(aws_ssm_parameter.this) == 0
    error_message = "publish_ssm_parameters = false no crea parámetros."
  }
}

run "rejects_prod_growth_without_vault_lock" {
  command = plan

  variables {
    environment = "prod"
  }

  expect_failures = [var.vault_lock]
}

run "accepts_prod_starter_without_vault_lock" {
  command = plan

  variables {
    environment = "prod"
    tier        = "starter"
  }

  assert {
    condition     = length(aws_backup_vault_lock_configuration.this) == 0
    error_message = "El tier starter no exige bloqueo de vault."
  }
}

run "rejects_vault_lock_with_less_than_3_days_of_cooling_off" {
  command = plan

  variables {
    vault_lock = { changeable_for_days = 1 }
  }

  expect_failures = [var.vault_lock]
}

run "rejects_retention_shorter_than_vault_lock_minimum" {
  command = plan

  variables {
    schedule   = { daily_retention_days = 5 }
    vault_lock = { min_retention_days = 7 }
  }

  expect_failures = [var.schedule]
}

run "rejects_monthly_retention_too_short_for_cold_storage" {
  command = plan

  variables {
    schedule = { monthly_retention_days = 100, monthly_cold_storage_after_days = 30 }
  }

  expect_failures = [var.schedule]
}

run "rejects_continuous_retention_above_35" {
  command = plan

  variables {
    schedule = { continuous_retention_days = 36 }
  }

  expect_failures = [var.schedule]
}

run "rejects_prod_with_short_daily_retention" {
  command = plan

  variables {
    environment = "prod"
    tier        = "starter"
    schedule    = { daily_retention_days = 7 }
  }

  expect_failures = [var.schedule]
}

run "rejects_plan_without_tier" {
  command = plan

  variables {
    tier = null
  }

  expect_failures = [var.tier]
}

run "rejects_unknown_tier" {
  command = plan

  variables {
    tier = "platinum"
  }

  expect_failures = [var.tier]
}

run "rejects_copy_destination_that_is_not_a_vault_arn" {
  command = plan

  variables {
    copy_destinations = {
      dr = { vault_arn = "arn:aws:s3:::bucket" }
    }
  }

  expect_failures = [var.copy_destinations]
}

run "rejects_copies_without_plan" {
  command = plan

  variables {
    plan_enabled = false
    tier         = null
    copy_destinations = {
      dr = { vault_arn = "arn:aws:backup:us-west-2:123456789012:backup-vault:acme-dev-dr" }
    }
  }

  expect_failures = [var.copy_destinations]
}

run "rejects_restore_testing_without_plan" {
  command = plan

  variables {
    plan_enabled    = false
    tier            = null
    restore_testing = {}
  }

  expect_failures = [var.restore_testing]
}

run "rejects_unsupported_restore_testing_type" {
  command = plan

  variables {
    restore_testing = { resource_types = ["Redshift"] }
  }

  expect_failures = [var.restore_testing]
}

run "rejects_alias_as_kms_key" {
  command = plan

  variables {
    kms_key_arn = "arn:aws:kms:us-east-1:123456789012:alias/acme"
  }

  expect_failures = [var.kms_key_arn]
}
