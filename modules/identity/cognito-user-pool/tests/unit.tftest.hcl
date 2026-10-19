mock_provider "aws" {
  mock_resource "aws_cognito_user_pool" {
    defaults = {
      id       = "us-east-1_EXAMPLE1"
      arn      = "arn:aws:cognito-idp:us-east-1:123456789012:userpool/us-east-1_EXAMPLE1"
      endpoint = "cognito-idp.us-east-1.amazonaws.com/us-east-1_EXAMPLE1"
    }
  }

  mock_resource "aws_cloudwatch_log_group" {
    defaults = {
      arn = "arn:aws:logs:us-east-1:123456789012:log-group:/aws/vendedlogs/cognito/acme-dev-tenants/notifications"
    }
  }

  mock_data "aws_region" {
    defaults = {
      region = "us-east-1"
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }
}

variables {
  project     = "acme"
  environment = "dev"
  name        = "tenants"
  kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/11111111-2222-3333-4444-555555555555"
}

run "prod_defaults_are_strict" {
  command = plan

  variables {
    environment = "prod"
    email = {
      sending_account    = "DEVELOPER"
      source_arn         = "arn:aws:ses:us-east-1:123456789012:identity/example.com"
      from_email_address = "no-reply@example.com"
    }
  }

  assert {
    condition = (
      aws_cognito_user_pool.this.mfa_configuration == "ON" &&
      length(aws_cognito_user_pool.this.software_token_mfa_configuration) == 1 &&
      aws_cognito_user_pool.this.software_token_mfa_configuration[0].enabled
    )
    error_message = "En prod la MFA es obligatoria (ON) con TOTP."
  }

  assert {
    condition     = aws_cognito_user_pool.this.deletion_protection == "ACTIVE" && aws_cognito_user_pool.this.user_pool_tier == "ESSENTIALS"
    error_message = "En prod el pool tiene protección contra borrado y el plan por defecto es ESSENTIALS."
  }

  assert {
    condition = (
      aws_cognito_user_pool.this.admin_create_user_config[0].allow_admin_create_user_only &&
      aws_cognito_user_pool.this.password_policy[0].minimum_length == 14 &&
      aws_cognito_user_pool.this.password_policy[0].require_symbols &&
      aws_cognito_user_pool.this.password_policy[0].password_history_size == 5 &&
      toset(aws_cognito_user_pool.this.username_attributes) == toset(["email"]) &&
      toset(aws_cognito_user_pool.this.user_attribute_update_settings[0].attributes_require_verification_before_update) == toset(["email"])
    )
    error_message = "Por defecto: solo el backend crea usuarios, contraseñas de 14+ con historial, correo como usuario y verificado antes de cambiarlo."
  }

  assert {
    condition     = alltrue([for m in aws_cognito_user_pool.this.account_recovery_setting[0].recovery_mechanism : m.name == "verified_email"])
    error_message = "La recuperación de cuenta es solo por correo verificado (sin SMS)."
  }

  assert {
    condition     = length(aws_cognito_risk_configuration.this) == 0 && length(aws_cognito_user_pool.this.user_pool_add_ons) == 0 && length(aws_cloudwatch_log_group.auth_events) == 0
    error_message = "Sin PLUS no hay threat protection ni logs de actividad."
  }
}

run "dev_defaults" {
  command = plan

  assert {
    condition     = aws_cognito_user_pool.this.mfa_configuration == "OPTIONAL" && aws_cognito_user_pool.this.deletion_protection == "INACTIVE"
    error_message = "En dev la MFA es OPTIONAL y el pool se puede borrar."
  }

  assert {
    condition     = aws_cognito_user_pool.this.email_configuration[0].email_sending_account == "COGNITO_DEFAULT"
    error_message = "Fuera de prod se admite el envío de correo de Cognito."
  }
}

run "lite_plan_has_no_password_history" {
  command = plan

  variables {
    feature_plan = "LITE"
  }

  assert {
    condition     = aws_cognito_user_pool.this.password_policy[0].password_history_size == null
    error_message = "El historial de contraseñas no existe en LITE."
  }
}

run "tenant_id_is_immutable_custom_attribute" {
  command = plan

  variables {
    tenant_id_attribute = true
  }

  assert {
    condition = length([
      for s in aws_cognito_user_pool.this.schema : s
      if s.name == "tenant_id" && s.attribute_data_type == "String" && s.mutable == false && s.developer_only_attribute == false
    ]) == 1
    error_message = "custom:tenant_id debe ser un atributo String inmutable."
  }

  assert {
    condition     = output.tenant_id_claim == "custom:tenant_id"
    error_message = "La salida tenant_id_claim indica el claim del ID token."
  }
}

run "public_clients_are_hardened" {
  command = plan

  variables {
    app_clients = {
      web = { callback_urls = ["https://app.example.com/callback"] }
    }
  }

  assert {
    condition = (
      aws_cognito_user_pool_client.this["web"].generate_secret == false &&
      toset(aws_cognito_user_pool_client.this["web"].allowed_oauth_flows) == toset(["code"]) &&
      toset(aws_cognito_user_pool_client.this["web"].supported_identity_providers) == toset(["COGNITO"]) &&
      aws_cognito_user_pool_client.this["web"].prevent_user_existence_errors == "ENABLED" &&
      aws_cognito_user_pool_client.this["web"].enable_token_revocation
    )
    error_message = "Clientes públicos: sin secreto, solo authorization code, sin errores que revelen usuarios y con revocación."
  }

  assert {
    condition = (
      toset(aws_cognito_user_pool_client.this["web"].explicit_auth_flows) == toset(["ALLOW_USER_SRP_AUTH"]) &&
      length(aws_cognito_user_pool_client.this["web"].refresh_token_rotation) == 1 &&
      aws_cognito_user_pool_client.this["web"].refresh_token_rotation[0].feature == "ENABLED"
    )
    error_message = "Con rotación de refresh tokens: solo SRP (sin ALLOW_REFRESH_TOKEN_AUTH ni USER_PASSWORD_AUTH)."
  }

  assert {
    condition = (
      aws_cognito_user_pool_client.this["web"].access_token_validity == 60 &&
      aws_cognito_user_pool_client.this["web"].token_validity_units[0].access_token == "minutes" &&
      aws_cognito_user_pool_client.this["web"].refresh_token_validity == 30 &&
      aws_cognito_user_pool_client.this["web"].token_validity_units[0].refresh_token == "days"
    )
    error_message = "Tokens de acceso de 60 minutos y refresh de 30 días por defecto, con unidades explícitas."
  }

  assert {
    condition     = !contains(aws_cognito_user_pool_client.this["web"].write_attributes, "custom:tenant_id")
    error_message = "El cliente no puede escribir custom:tenant_id."
  }
}

run "client_without_rotation_keeps_refresh_flow" {
  command = plan

  variables {
    app_clients = {
      mobile = { callback_urls = ["https://app.example.com/m"], refresh_token_rotation = false }
    }
  }

  assert {
    condition = (
      toset(aws_cognito_user_pool_client.this["mobile"].explicit_auth_flows) == toset(["ALLOW_USER_SRP_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]) &&
      length(aws_cognito_user_pool_client.this["mobile"].refresh_token_rotation) == 0
    )
    error_message = "Sin rotación, el cliente refresca con ALLOW_REFRESH_TOKEN_AUTH."
  }
}

run "plus_enables_threat_protection_and_activity_logs" {
  command = plan

  variables {
    environment       = "prod"
    feature_plan      = "PLUS"
    mfa_configuration = "OPTIONAL"
    email = {
      sending_account = "DEVELOPER"
      source_arn      = "arn:aws:ses:us-east-1:123456789012:identity/example.com"
    }
  }

  assert {
    condition     = aws_cognito_user_pool.this.user_pool_add_ons[0].advanced_security_mode == "ENFORCED"
    error_message = "En prod la threat protection se aplica (ENFORCED)."
  }

  assert {
    condition = (
      aws_cognito_risk_configuration.this[0].compromised_credentials_risk_configuration[0].actions[0].event_action == "BLOCK" &&
      toset(aws_cognito_risk_configuration.this[0].compromised_credentials_risk_configuration[0].event_filter) == toset(["SIGN_IN", "SIGN_UP", "PASSWORD_CHANGE"])
    )
    error_message = "Las credenciales comprometidas se bloquean en inicio de sesión, alta y cambio de contraseña."
  }

  assert {
    condition = (
      aws_cognito_risk_configuration.this[0].account_takeover_risk_configuration[0].actions[0].low_action[0].event_action == "NO_ACTION" &&
      aws_cognito_risk_configuration.this[0].account_takeover_risk_configuration[0].actions[0].medium_action[0].event_action == "MFA_IF_CONFIGURED" &&
      aws_cognito_risk_configuration.this[0].account_takeover_risk_configuration[0].actions[0].high_action[0].event_action == "MFA_REQUIRED" &&
      aws_cognito_risk_configuration.this[0].account_takeover_risk_configuration[0].actions[0].high_action[0].notify == false &&
      length(aws_cognito_risk_configuration.this[0].account_takeover_risk_configuration[0].notify_configuration) == 0
    )
    error_message = "Autenticación adaptativa por defecto: bajo sin acción, medio MFA si está configurada, alto MFA obligatoria; sin SES no se notifica."
  }

  assert {
    condition = (
      length(aws_cloudwatch_log_group.auth_events) == 1 &&
      toset([for c in aws_cognito_log_delivery_configuration.this.log_configurations : "${c.event_source}/${c.log_level}"]) == toset(["userAuthEvents/INFO"]) &&
      length(aws_cloudwatch_log_group.notifications) == 0
    )
    error_message = "En PLUS se entregan los eventos de actividad (INFO) a su log group (una sola configuración por pool)."
  }
}

run "plus_audits_outside_prod_and_notifies_with_ses" {
  command = plan

  variables {
    feature_plan = "PLUS"
    threat_protection = {
      notify = { source_arn = "arn:aws:ses:us-east-1:123456789012:identity/example.com", from = "no-reply@example.com" }
    }
  }

  assert {
    condition     = aws_cognito_user_pool.this.user_pool_add_ons[0].advanced_security_mode == "AUDIT"
    error_message = "Fuera de prod la threat protection empieza en AUDIT."
  }

  assert {
    condition = (
      aws_cognito_risk_configuration.this[0].account_takeover_risk_configuration[0].actions[0].medium_action[0].notify &&
      aws_cognito_risk_configuration.this[0].account_takeover_risk_configuration[0].actions[0].high_action[0].notify &&
      aws_cognito_risk_configuration.this[0].account_takeover_risk_configuration[0].notify_configuration[0].source_arn == "arn:aws:ses:us-east-1:123456789012:identity/example.com"
    )
    error_message = "Con identidad SES se avisa al usuario en riesgo medio y alto."
  }
}

run "managed_login_with_prefix" {
  command = plan

  variables {
    domain = { prefix = "acme-dev-tenants" }
    app_clients = {
      web = { callback_urls = ["https://app.example.com/callback"] }
    }
  }

  assert {
    condition     = aws_cognito_user_pool_domain.this[0].domain == "acme-dev-tenants" && aws_cognito_user_pool_domain.this[0].managed_login_version == 2 && aws_cognito_user_pool_domain.this[0].certificate_arn == null
    error_message = "Dominio con prefijo y managed login versión 2."
  }

  assert {
    condition     = length(aws_cognito_managed_login_branding.this) == 1 && aws_cognito_managed_login_branding.this["web"].use_cognito_provided_values
    error_message = "Cada app client tiene un estilo de managed login."
  }

  assert {
    condition     = output.domain_url == "https://acme-dev-tenants.auth.us-east-1.amazoncognito.com"
    error_message = "domain_url es el dominio de Cognito de la región."
  }
}

run "custom_domain_uses_us_east_1_certificate" {
  command = plan

  variables {
    domain = {
      custom_domain   = "auth.example.com"
      certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/11111111-2222-3333-4444-555555555555"
    }
  }

  assert {
    condition     = aws_cognito_user_pool_domain.this[0].domain == "auth.example.com" && aws_cognito_user_pool_domain.this[0].certificate_arn != null && output.domain_url == "https://auth.example.com"
    error_message = "Dominio propio con su certificado de us-east-1."
  }
}

run "no_domain_by_default" {
  command = plan

  assert {
    condition     = length(aws_cognito_user_pool_domain.this) == 0 && output.domain_url == null && output.custom_domain_alias == null
    error_message = "Sin domain no hay managed login."
  }
}

run "pre_token_generation_v2_trigger_and_permission" {
  command = plan

  variables {
    pre_token_generation_lambda_arn = "arn:aws:lambda:us-east-1:123456789012:function:acme-dev-pre-token"
  }

  assert {
    condition = (
      aws_cognito_user_pool.this.lambda_config[0].pre_token_generation_config[0].lambda_version == "V2_0" &&
      aws_cognito_user_pool.this.lambda_config[0].pre_token_generation_config[0].lambda_arn == "arn:aws:lambda:us-east-1:123456789012:function:acme-dev-pre-token"
    )
    error_message = "El trigger usa la versión V2_0 (personaliza también el access token)."
  }

  assert {
    condition = (
      aws_lambda_permission.pre_token_generation[0].principal == "cognito-idp.amazonaws.com" &&
      aws_lambda_permission.pre_token_generation[0].source_account == "123456789012"
    )
    error_message = "Solo Cognito de esta cuenta puede invocar el trigger."
  }
}

run "groups_by_stable_name" {
  command = plan

  variables {
    groups = {
      admins = { precedence = 1 }
      users  = {}
    }
  }

  assert {
    condition     = toset(keys(aws_cognito_user_group.this)) == toset(["admins", "users"]) && aws_cognito_user_group.this["admins"].precedence == 1
    error_message = "Un grupo por clave con su precedencia."
  }
}

run "logs_encrypted_and_ssm_published" {
  command = plan

  variables {
    app_clients = {
      web = { callback_urls = ["https://app.example.com/callback"] }
    }
  }

  assert {
    condition = (
      aws_cloudwatch_log_group.notifications[0].name == "/aws/vendedlogs/cognito/acme-dev-tenants/notifications" &&
      aws_cloudwatch_log_group.notifications[0].kms_key_id == "arn:aws:kms:us-east-1:123456789012:key/11111111-2222-3333-4444-555555555555" &&
      aws_cloudwatch_log_group.notifications[0].retention_in_days == 365
    )
    error_message = "Los errores de envío van a un log group bajo /aws/vendedlogs, cifrado con la CMK y con retención."
  }

  assert {
    condition     = toset(keys(aws_ssm_parameter.this)) == toset(["user_pool_id", "user_pool_arn", "issuer", "client_id/web"])
    error_message = "SSM publica el pool, el emisor y los IDs de cliente."
  }
}

run "issuer_and_jwks_from_pool_endpoint" {
  command = apply

  assert {
    condition = (
      output.issuer_url == "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_EXAMPLE1" &&
      output.jwks_uri == "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_EXAMPLE1/.well-known/jwks.json"
    )
    error_message = "issuer_url y jwks_uri salen del endpoint del pool."
  }
}

run "rejects_mfa_off_in_prod" {
  command = plan

  variables {
    environment       = "prod"
    mfa_configuration = "OFF"
    email             = { sending_account = "DEVELOPER", source_arn = "arn:aws:ses:us-east-1:123456789012:identity/example.com" }
  }

  expect_failures = [var.mfa_configuration]
}

run "rejects_optional_mfa_in_prod_without_plus" {
  command = plan

  variables {
    environment       = "prod"
    mfa_configuration = "OPTIONAL"
    email             = { sending_account = "DEVELOPER", source_arn = "arn:aws:ses:us-east-1:123456789012:identity/example.com" }
  }

  expect_failures = [var.mfa_configuration]
}

run "rejects_cognito_email_in_prod" {
  command = plan

  variables {
    environment = "prod"
  }

  expect_failures = [var.email]
}

run "rejects_deletion_protection_off_in_prod" {
  command = plan

  variables {
    environment         = "prod"
    deletion_protection = false
    email               = { sending_account = "DEVELOPER", source_arn = "arn:aws:ses:us-east-1:123456789012:identity/example.com" }
  }

  expect_failures = [var.deletion_protection]
}

run "rejects_short_passwords" {
  command = plan

  variables {
    password_policy = { minimum_length = 8 }
  }

  expect_failures = [var.password_policy]
}

run "rejects_clients_writing_tenant_id" {
  command = plan

  variables {
    app_clients = {
      web = { callback_urls = ["https://app.example.com/callback"], write_attributes = ["email", "custom:tenant_id"] }
    }
  }

  expect_failures = [var.app_clients]
}

run "rejects_plain_http_callbacks" {
  command = plan

  variables {
    app_clients = {
      web = { callback_urls = ["http://app.example.com/callback"] }
    }
  }

  expect_failures = [var.app_clients]
}

run "rejects_localhost_callbacks_in_prod" {
  command = plan

  variables {
    environment = "prod"
    email       = { sending_account = "DEVELOPER", source_arn = "arn:aws:ses:us-east-1:123456789012:identity/example.com" }
    app_clients = {
      web = { callback_urls = ["http://localhost:3000/callback"] }
    }
  }

  expect_failures = [var.app_clients]
}

run "rejects_long_lived_access_tokens" {
  command = plan

  variables {
    app_clients = {
      web = { callback_urls = ["https://app.example.com/callback"], access_token_validity_minutes = 120 }
    }
  }

  expect_failures = [var.app_clients]
}

run "rejects_domain_with_prefix_and_custom_domain" {
  command = plan

  variables {
    domain = {
      prefix          = "acme-dev"
      custom_domain   = "auth.example.com"
      certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/11111111-2222-3333-4444-555555555555"
    }
  }

  expect_failures = [var.domain]
}

run "rejects_reserved_words_in_prefix" {
  command = plan

  variables {
    domain = { prefix = "acme-cognito-login" }
  }

  expect_failures = [var.domain]
}

run "rejects_regional_certificate_for_custom_domain" {
  command = plan

  variables {
    domain = {
      custom_domain   = "auth.example.com"
      certificate_arn = "arn:aws:acm:eu-west-1:123456789012:certificate/11111111-2222-3333-4444-555555555555"
    }
  }

  expect_failures = [var.domain]
}

run "rejects_self_registration_with_tenant_attribute" {
  command = plan

  variables {
    self_registration_enabled = true
    tenant_id_attribute       = true
  }

  expect_failures = [var.self_registration_enabled]
}

run "rejects_pre_token_v2_on_lite" {
  command = plan

  variables {
    feature_plan                    = "LITE"
    pre_token_generation_lambda_arn = "arn:aws:lambda:us-east-1:123456789012:function:acme-dev-pre-token"
  }

  expect_failures = [var.pre_token_generation_lambda_arn]
}

run "rejects_unknown_risk_action" {
  command = plan

  variables {
    threat_protection = { high_action = "CAPTCHA" }
  }

  expect_failures = [var.threat_protection]
}

run "rejects_pre_token_flag_without_lambda" {
  command = plan

  variables {
    pre_token_generation_enabled = true
  }

  expect_failures = [var.pre_token_generation_enabled]
}

run "non_plus_pools_log_notification_errors" {
  command = plan

  assert {
    condition = (
      length(aws_cognito_log_delivery_configuration.this.log_configurations) == 1 &&
      aws_cognito_log_delivery_configuration.this.log_configurations[0].event_source == "userNotification"
    )
    error_message = "Fuera de PLUS se registran solo los errores de envío (una configuración por pool)."
  }
}
