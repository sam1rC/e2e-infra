# Módulo auxiliar de la prueba de integración: hace la misma petición sin y con la cabecera de verificación
# de origen y devuelve los códigos de estado.
terraform {
  required_version = ">= 1.11.0"

  required_providers {
    http = {
      source  = "hashicorp/http"
      version = ">= 3.4, < 4.0"
    }
  }
}

variable "url" {
  description = "URL a la que llamar (directamente al endpoint execute-api, sin pasar por CloudFront)."
  type        = string
}

variable "origin_verify_token" {
  description = "Valor de la cabecera x-origin-verify."
  type        = string
  sensitive   = true
}

data "http" "without_header" {
  url = var.url

  retry {
    attempts     = 6
    min_delay_ms = 5000
  }
}

data "http" "with_header" {
  url = var.url

  request_headers = {
    x-origin-verify = var.origin_verify_token
  }

  retry {
    attempts     = 6
    min_delay_ms = 5000
  }
}

output "without_header_status" {
  description = "Código de estado sin la cabecera de origen."
  value       = data.http.without_header.status_code
}

output "with_header_status" {
  description = "Código de estado con la cabecera de origen pero sin token."
  value       = data.http.with_header.status_code
}
