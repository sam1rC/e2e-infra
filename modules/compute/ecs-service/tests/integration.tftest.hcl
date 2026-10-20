# Requiere credenciales de la cuenta sandbox, un certificado ACM EMITIDO en us-east-1 y una imagen
# real por digest en tu ECR (variables de examples/complete). Corre solo en main/nightly:
#   tofu test -filter=tests/integration.tftest.hcl -var certificate_arn=... -var image=...
# `tofu test` destruye todo al terminar. La idempotencia (plan sin cambios) se comprueba
# además con `tofu plan -detailed-exitcode` sobre examples/complete en el job de CI.
#
# Criterios de aceptación de la fase 5 (en tests/e2e/, fase 12): la imagen nginx re-etiquetada en ECR
# responde 200 a través de CloudFront → ALB interno; un despliegue con imagen rota hace rollback
# automático (circuit breaker); las tareas no tienen IP pública.

variables {
  certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/REEMPLAZAR"
  image           = "123456789012.dkr.ecr.us-east-1.amazonaws.com/REEMPLAZAR@sha256:0000000000000000000000000000000000000000000000000000000000000000"
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
    condition     = startswith(output.service_name, "acme-") && endswith(output.service_name, "-dev-web")
    error_message = "El servicio ECS debe crearse con el nombre <project>-<environment>-<name>."
  }

  assert {
    condition     = can(regex("^internal-", output.alb_dns_name))
    error_message = "El ALB debe ser interno."
  }
}
