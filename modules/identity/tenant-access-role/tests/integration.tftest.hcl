# Requiere credenciales de la cuenta sandbox. Corre solo en main/nightly:
#   tofu test -filter=tests/integration.tftest.hcl
# `tofu test` destruye todo al terminar. La prueba de comportamiento (un tenant no lee filas ni objetos de
# otro, Scan denegado) está en tests/integration/tenant-isolation/dynamodb-s3.sh y se lanza aparte sobre
# examples/complete con -var test_principal_arns='["<ARN del ejecutor>"]'.

run "apply_complete_example" {
  command = apply

  module {
    source = "./examples/complete"
  }

  variables {
    name_suffix = formatdate("hhmmss", timestamp())
  }

  assert {
    condition     = can(regex("^arn:aws:iam::[0-9]{12}:role/acme-[0-9]+-dev-tenant-access$", output.role_arn))
    error_message = "El rol de acceso del tenant debe crearse."
  }
}
