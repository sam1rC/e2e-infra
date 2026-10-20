# Requiere credenciales de la cuenta sandbox y un certificado ACM EMITIDO en us-east-1 que cubra
# `domain_name` (variables de examples/complete). Corre solo en main/nightly:
#   tofu test -filter=tests/integration.tftest.hcl -var certificate_arn=... -var domain_name=...
# `tofu test` destruye todo al terminar. La idempotencia (plan sin cambios) se comprueba
# además con `tofu plan -detailed-exitcode` sobre examples/complete en el job de CI.
#
# Es la verificación real del VPC origin con la versión del provider elegida (ADR 0001): había una
# regresión en 6.17. Las comprobaciones E2E (HTTPS 200 de extremo a extremo con https-only, el DNS del
# ALB sin IP pública, SQLi bloqueado por el WAF) están en tests/e2e/ (fase 12).

variables {
  certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/REEMPLAZAR"
  domain_name     = "app.example.com"
}

run "apply_complete_example" {
  command = apply

  module {
    source = "./examples/complete"
  }

  variables {
    name_suffix = formatdate("hhmmss", timestamp())
  }

  assert {
    condition     = endswith(output.distribution_domain_name, ".cloudfront.net")
    error_message = "La distribución con VPC origin debe crearse."
  }
}
