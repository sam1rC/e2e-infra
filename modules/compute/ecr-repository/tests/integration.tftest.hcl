# Requiere credenciales de la cuenta sandbox. Corre solo en main/nightly:
#   tofu test -filter=tests/integration.tftest.hcl
# `tofu test` destruye todo al terminar. La idempotencia (plan sin cambios) se comprueba
# además con `tofu plan -detailed-exitcode` sobre examples/complete en el job de CI.
#
# El pull desde una tarea Fargate sin tráfico NAT (vía endpoints de ECR + gateway de S3) y el
# rechazo de un segundo push con la misma etiqueta están en tests/e2e/ (fase 12).

run "apply_complete_example" {
  command = apply

  module {
    source = "./examples/complete"
  }

  variables {
    name_suffix = formatdate("hhmmss", timestamp())
  }

  assert {
    condition     = can(regex("\\.dkr\\.ecr\\.[a-z0-9-]+\\.amazonaws\\.com/acme-dev-web-", output.repository_url))
    error_message = "El repositorio debe crearse y devolver su URL."
  }
}
