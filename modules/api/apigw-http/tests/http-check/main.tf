# Módulo auxiliar de la prueba de integración: hace dos peticiones HTTP y devuelve sus códigos de estado.
terraform {
  required_version = ">= 1.11.0"

  required_providers {
    http = {
      source  = "hashicorp/http"
      version = ">= 3.4, < 4.0"
    }
  }
}

variable "protected_url" {
  description = "URL de una ruta con autorizador JWT."
  type        = string
}

variable "public_url" {
  description = "URL de una ruta pública."
  type        = string
}

data "http" "protected" {
  url = var.protected_url

  retry {
    attempts     = 5
    min_delay_ms = 2000
  }
}

data "http" "public" {
  url = var.public_url

  retry {
    attempts     = 5
    min_delay_ms = 2000
  }
}

output "protected_status" {
  description = "Código de estado de la ruta protegida."
  value       = data.http.protected.status_code
}

output "public_status" {
  description = "Código de estado de la ruta pública."
  value       = data.http.public.status_code
}
