# Requiere credenciales de la cuenta sandbox. Corre solo en main/nightly:
#   tofu test -filter=tests/integration.tftest.hcl
# `tofu test` destruye todo al terminar. La idempotencia (plan sin cambios) se comprueba
# además con `tofu plan -detailed-exitcode` sobre examples/complete en el job de CI.

run "apply_complete_example" {
  command = apply

  module {
    source = "./examples/complete"
  }

  variables {
    name_suffix = formatdate("YYYYMMDDhhmmss", timestamp())
  }

  assert {
    condition     = can(regex("^arn:aws:s3:::", output.bucket_arn))
    error_message = "El bucket debe crearse y devolver su ARN."
  }
}
