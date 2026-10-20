# Clientes públicos (SPA/móvil): sin secreto, authorization code + PKCE y solo SRP para la autenticación directa.
resource "aws_cognito_user_pool_client" "this" {
  for_each = var.app_clients

  name         = "${local.name}-${each.key}"
  user_pool_id = aws_cognito_user_pool.this.id

  generate_secret                      = false
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = each.value.oauth_scopes
  callback_urls                        = each.value.callback_urls
  logout_urls                          = each.value.logout_urls
  supported_identity_providers         = ["COGNITO"]

  # Con rotación de refresh tokens, ALLOW_REFRESH_TOKEN_AUTH no está disponible: se refresca con
  # GetTokensFromRefreshToken o con el endpoint /oauth2/token.
  explicit_auth_flows = each.value.refresh_token_rotation ? ["ALLOW_USER_SRP_AUTH"] : ["ALLOW_USER_SRP_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]

  prevent_user_existence_errors = "ENABLED"
  enable_token_revocation       = true
  auth_session_validity         = 3

  access_token_validity  = each.value.access_token_validity_minutes
  id_token_validity      = each.value.id_token_validity_minutes
  refresh_token_validity = each.value.refresh_token_validity_days

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }

  dynamic "refresh_token_rotation" {
    for_each = each.value.refresh_token_rotation ? [1] : []

    content {
      feature                    = "ENABLED"
      retry_grace_period_seconds = 30
    }
  }

  read_attributes  = each.value.read_attributes
  write_attributes = each.value.write_attributes
}

# Managed login (versión 2): cada app client necesita un estilo para mostrar las páginas de inicio de sesión.
resource "aws_cognito_managed_login_branding" "this" {
  for_each = local.managed_login ? var.app_clients : {}

  user_pool_id                = aws_cognito_user_pool.this.id
  client_id                   = aws_cognito_user_pool_client.this[each.key].id
  use_cognito_provided_values = true
}

resource "aws_cognito_user_pool_domain" "this" {
  count = local.managed_login ? 1 : 0

  user_pool_id          = aws_cognito_user_pool.this.id
  domain                = local.custom_domain ? var.domain.custom_domain : var.domain.prefix
  certificate_arn       = local.custom_domain ? var.domain.certificate_arn : null
  managed_login_version = 2
}
