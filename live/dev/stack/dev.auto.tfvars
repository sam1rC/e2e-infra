# Valores comunes generados desde client.yaml por scripts/new-client.sh (sin secretos).
account_id          = "654654616677"
region              = "us-east-1"
project             = "e2e"
environment         = "dev"
blueprint           = "saas-t3"
owner               = "samir"
cost_center         = "catalog-test"
data_classification = "internal"
extra_tags          = {}

# --- Capa stack ---
domain_name  = "dev.e2e.catalog-sandbox.click"
zone_id      = "Z0322739RP72CHC4DRCP"
alarm_emails = ["samircolpas14@gmail.com"]

# Código de la Lambda de la API: el pipeline de la aplicación sube el zip al bucket de artefactos que crea
# live/_bootstrap/sandbox-dev (sube una primera versión antes del primer apply) y fija s3_object_version.
api_function = {
  s3_bucket = "e2e-dev-artifacts-654654616677"
  s3_key    = "api/app.zip"
  # s3_object_version = "..."
  # runtime           = "python3.13"
  # handler           = "app.handler"
}

# Planes de uso por tier (throttling y cuota por API key; el onboarding asocia la clave de cada tenant):
# usage_plans = { basic = { rate_limit = 10, burst_limit = 20, quota_limit = 100000 }, pro = { rate_limit = 50, burst_limit = 100 } }

# En prod Cognito debe enviar el correo por SES (sending_account = DEVELOPER): define environments.<env>.email en client.yaml.
# auth = { email = { sending_account = "DEVELOPER", source_arn = "arn:aws:ses:...:identity/...", from_email_address = "no-reply@..." } }
