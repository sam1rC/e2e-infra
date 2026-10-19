# Requiere credenciales de la cuenta sandbox y un certificado ACM EMITIDO en us-east-1 que cubra el
# dominio de la aplicación (variable certificate_arn de examples/complete). Corre solo en main/nightly:
#   tofu test -filter=tests/integration.tftest.hcl -var certificate_arn=...
# `tofu test` destruye todo al terminar. La idempotencia (plan sin cambios) se comprueba
# además con `tofu plan -detailed-exitcode` sobre examples/complete en el job de CI.
#
# Las comprobaciones de red (el DNS del ALB resuelve solo a IPs privadas, el 404 por defecto al
# llegar por el DNS interno) están en tests/e2e/ (fase 12).

variables {
  certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/REEMPLAZAR"
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
    condition     = can(regex("^internal-", output.alb_dns_name))
    error_message = "El ALB debe ser interno (su DNS empieza por internal-)."
  }

  assert {
    condition     = length(output.target_group_arns) == 2
    error_message = "Deben crearse los dos target groups."
  }
}
