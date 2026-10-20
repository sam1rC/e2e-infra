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

  mock_data "aws_region" {
    defaults = {
      region = "us-east-1"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  mock_resource "aws_kms_key" {
    defaults = {
      arn = "arn:aws:kms:us-east-1:123456789012:key/11111111-2222-3333-4444-555555555555"
    }
  }

  mock_resource "aws_cloudwatch_log_group" {
    defaults = {
      arn = "arn:aws:logs:us-east-1:123456789012:log-group:/aws/cloudtrail/mock"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/mock"
    }
  }

  mock_resource "aws_sns_topic" {
    defaults = {
      arn = "arn:aws:sns:us-east-1:123456789012:mock"
    }
  }

  mock_resource "aws_cloudwatch_event_rule" {
    defaults = {
      arn = "arn:aws:events:us-east-1:123456789012:rule/mock"
    }
  }

  mock_resource "aws_ce_anomaly_monitor" {
    defaults = {
      arn = "arn:aws:ce::123456789012:anomalymonitor/11111111-2222-3333-4444-555555555555"
    }
  }
}

variables {
  project      = "acme"
  environment  = "dev"
  alert_emails = ["security@example.com"]
}

run "cloudtrail_is_multi_region_validated_and_encrypted" {
  command = plan

  assert {
    condition = alltrue([
      aws_cloudtrail.this.is_multi_region_trail,
      aws_cloudtrail.this.include_global_service_events,
      aws_cloudtrail.this.enable_log_file_validation,
    ])
    error_message = "El trail debe ser multi-región, con eventos globales y validación de ficheros."
  }

  assert {
    condition     = aws_cloudtrail.this.name == "acme-dev-trail"
    error_message = "El trail debe llamarse <project>-<env>-trail."
  }
}

run "cloudtrail_only_has_management_selector_by_default" {
  command = plan

  assert {
    condition     = length(aws_cloudtrail.this.advanced_event_selector) == 1
    error_message = "Por defecto solo se registran eventos de gestión."
  }
}

run "cloudtrail_s3_data_events_optional" {
  command = plan

  variables {
    cloudtrail = { s3_data_events = true }
  }

  assert {
    condition     = length(aws_cloudtrail.this.advanced_event_selector) == 2
    error_message = "s3_data_events debe añadir el selector de datos de S3."
  }
}

run "account_defaults_are_closed" {
  command = plan

  assert {
    condition = alltrue([
      aws_s3_account_public_access_block.this.block_public_acls,
      aws_s3_account_public_access_block.this.block_public_policy,
      aws_s3_account_public_access_block.this.ignore_public_acls,
      aws_s3_account_public_access_block.this.restrict_public_buckets,
    ])
    error_message = "El bloqueo de acceso público de cuenta debe estar completo."
  }

  assert {
    condition     = aws_ebs_encryption_by_default.this.enabled
    error_message = "El cifrado EBS por defecto debe estar activado."
  }

  assert {
    condition     = aws_iam_account_password_policy.this.minimum_password_length == 14 && aws_iam_account_password_policy.this.password_reuse_prevention == 24
    error_message = "Política de contraseñas por defecto incorrecta."
  }
}

run "guardduty_polls_every_15_minutes_and_toggles_features" {
  command = plan

  assert {
    condition     = aws_guardduty_detector.this.finding_publishing_frequency == "FIFTEEN_MINUTES" && aws_guardduty_detector.this.enable
    error_message = "GuardDuty debe estar activo con publicación cada 15 minutos."
  }

  assert {
    condition = (
      aws_guardduty_detector_feature.this["S3_DATA_EVENTS"].status == "ENABLED" &&
      aws_guardduty_detector_feature.this["EKS_AUDIT_LOGS"].status == "DISABLED"
    )
    error_message = "S3 activado y EKS desactivado por defecto."
  }
}

run "securityhub_subscribes_both_standards_without_defaults" {
  command = plan

  assert {
    condition     = aws_securityhub_account.this.enable_default_standards == false && length(aws_securityhub_standards_subscription.this) == 2
    error_message = "Deben suscribirse exactamente FSBP y CIS, sin estándares por defecto."
  }

  assert {
    condition = (
      aws_securityhub_standards_subscription.this["foundational"].standards_arn == "arn:aws:securityhub:us-east-1::standards/aws-foundational-security-best-practices/v/1.0.0" &&
      aws_securityhub_standards_subscription.this["cis"].standards_arn == "arn:aws:securityhub:us-east-1::standards/cis-aws-foundations-benchmark/v/5.0.0"
    )
    error_message = "ARNs de estándares inesperados."
  }
}

run "securityhub_standards_can_be_disabled" {
  command = plan

  variables {
    security_hub_standards = { cis = false }
  }

  assert {
    condition     = length(aws_securityhub_standards_subscription.this) == 1 && contains(keys(aws_securityhub_standards_subscription.this), "foundational")
    error_message = "Con cis = false solo debe quedar FSBP."
  }
}

run "config_records_everything" {
  command = plan

  assert {
    condition     = alltrue([for g in aws_config_configuration_recorder.this.recording_group : g.all_supported])
    error_message = "AWS Config debe grabar todos los tipos de recurso soportados."
  }

  assert {
    condition     = aws_config_configuration_recorder_status.this.is_enabled
    error_message = "El recorder debe estar activo."
  }
}

run "alerts_have_one_subscription_per_email_and_two_rules" {
  command = plan

  variables {
    alert_emails = ["a@example.com", "b@example.com"]
  }

  assert {
    condition     = length(aws_sns_topic_subscription.alerts_email) == 2
    error_message = "Debe haber una suscripción por correo."
  }

  assert {
    condition     = jsondecode(aws_cloudwatch_event_rule.guardduty_high.event_pattern).detail.severity[0].numeric == [">=", 7]
    error_message = "La regla de GuardDuty debe filtrar severidad >= 7."
  }

  assert {
    condition     = jsondecode(aws_cloudwatch_event_rule.securityhub_high.event_pattern).detail.findings.Severity.Label == ["CRITICAL", "HIGH"]
    error_message = "La regla de Security Hub debe filtrar CRITICAL y HIGH."
  }
}

run "local_log_bucket_by_default" {
  command = plan

  assert {
    condition     = length(module.log_bucket) == 1
    error_message = "Sin log_archive el módulo crea el bucket de logs."
  }
}

run "external_log_archive_skips_local_bucket" {
  command = plan

  variables {
    log_archive = {
      bucket_name = "org-log-archive"
      kms_key_arn = "arn:aws:kms:us-east-1:999999999999:key/11111111-2222-3333-4444-555555555555"
    }
  }

  assert {
    condition     = length(module.log_bucket) == 0 && aws_cloudtrail.this.s3_bucket_name == "org-log-archive"
    error_message = "Con log_archive no se crea bucket local y el trail usa el externo."
  }
}

run "cloudwatch_retention_rounds_up_to_supported_value" {
  command = plan

  variables {
    log_retention_days = 500
  }

  assert {
    condition     = aws_cloudwatch_log_group.cloudtrail.retention_in_days == 545
    error_message = "500 días deben redondearse a 545, el valor admitido siguiente."
  }
}

run "budget_is_optional" {
  command = plan

  assert {
    condition     = length(module.budgets) == 0
    error_message = "Sin budget no se crea el módulo budgets."
  }
}

run "budget_module_created_when_requested" {
  command = plan

  variables {
    budget = {
      monthly_limit_usd = 500
      alert_emails      = ["finance@example.com"]
    }
  }

  assert {
    condition     = length(module.budgets) == 1
    error_message = "Con budget debe crearse el módulo budgets."
  }
}

run "rejects_missing_alert_emails" {
  command = plan

  variables {
    alert_emails = []
  }

  expect_failures = [var.alert_emails]
}

run "rejects_short_retention" {
  command = plan

  variables {
    log_retention_days = 30
  }

  expect_failures = [var.log_retention_days]
}

run "rejects_weak_password_policy" {
  command = plan

  variables {
    password_policy = { minimum_length = 8 }
  }

  expect_failures = [var.password_policy]
}

run "rejects_unknown_analyzer_type" {
  command = plan

  variables {
    access_analyzer_type = "GLOBAL"
  }

  expect_failures = [var.access_analyzer_type]
}
