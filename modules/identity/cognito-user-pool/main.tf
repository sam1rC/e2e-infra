resource "aws_cognito_user_pool" "this" {
  name                = local.name
  user_pool_tier      = var.feature_plan
  deletion_protection = local.deletion_protection ? "ACTIVE" : "INACTIVE"

  # El correo es el nombre de usuario (fijo al crear el pool) y se verifica al darse de alta.
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  username_configuration {
    case_sensitive = false
  }

  mfa_configuration = local.mfa_configuration

  # TOTP como único factor: sin SMS (coste y factor más débil).
  dynamic "software_token_mfa_configuration" {
    for_each = local.mfa_configuration == "OFF" ? [] : [1]

    content {
      enabled = true
    }
  }

  password_policy {
    minimum_length                   = var.password_policy.minimum_length
    require_lowercase                = var.password_policy.require_lowercase
    require_uppercase                = var.password_policy.require_uppercase
    require_numbers                  = var.password_policy.require_numbers
    require_symbols                  = var.password_policy.require_symbols
    temporary_password_validity_days = var.password_policy.temporary_password_validity_days
    password_history_size            = var.feature_plan == "LITE" ? null : var.password_policy.password_history_size
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  admin_create_user_config {
    allow_admin_create_user_only = !var.self_registration_enabled
  }

  # Un cambio de correo no se aplica hasta verificar el nuevo (evita secuestrar la cuenta cambiándolo).
  user_attribute_update_settings {
    attributes_require_verification_before_update = ["email"]
  }

  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
  }

  email_configuration {
    email_sending_account  = var.email.sending_account
    source_arn             = var.email.sending_account == "DEVELOPER" ? var.email.source_arn : null
    from_email_address     = var.email.from_email_address
    reply_to_email_address = var.email.reply_to
    configuration_set      = var.email.configuration_set
  }

  # Tenant del usuario: inmutable y fuera de write_attributes de los app clients (lo fija el onboarding).
  dynamic "schema" {
    for_each = var.tenant_id_attribute ? [1] : []

    content {
      name                     = "tenant_id"
      attribute_data_type      = "String"
      mutable                  = false
      required                 = false
      developer_only_attribute = false

      string_attribute_constraints {
        min_length = "1"
        max_length = "64"
      }
    }
  }

  dynamic "user_pool_add_ons" {
    for_each = local.plus ? [1] : []

    content {
      advanced_security_mode = local.threat_mode
    }
  }

  dynamic "lambda_config" {
    for_each = local.pre_token ? [1] : []

    content {
      pre_token_generation_config {
        lambda_arn     = var.pre_token_generation_lambda_arn
        lambda_version = "V2_0"
      }
    }
  }

  tags = merge(var.tags, { Name = local.name })
}

resource "aws_cognito_user_group" "this" {
  for_each = var.groups

  user_pool_id = aws_cognito_user_pool.this.id
  name         = each.key
  description  = each.value.description
  precedence   = each.value.precedence
}

resource "aws_lambda_permission" "pre_token_generation" {
  count = local.pre_token ? 1 : 0

  statement_id   = "AllowCognitoPreTokenGeneration-${local.name}"
  action         = "lambda:InvokeFunction"
  function_name  = var.pre_token_generation_lambda_arn
  principal      = "cognito-idp.amazonaws.com"
  source_arn     = aws_cognito_user_pool.this.arn
  source_account = data.aws_caller_identity.current.account_id
}
