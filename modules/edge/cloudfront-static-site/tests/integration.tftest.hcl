# Requiere credenciales de la cuenta sandbox y un certificado ACM EMITIDO en us-east-1 que cubra
# `domain_name` (variables de examples/complete). Corre solo en main/nightly:
#   tofu test -filter=tests/integration.tftest.hcl
# `tofu test` destruye todo al terminar. La idempotencia (plan sin cambios) se comprueba
# además con `tofu plan -detailed-exitcode` sobre examples/complete en el job de CI.
#
# Comprobaciones de comportamiento (en tests/e2e/, fase 12): el bucket responde 403 a una petición
# directa, el sitio sirve por HTTPS con HSTS y TLS 1.2+, y /api/* llega al origen con x-origin-verify.

variables {
  certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/REEMPLAZAR"
  domain_name     = "www.example.com"
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
    error_message = "La distribución con origen S3 (OAC) debe crearse."
  }
}
