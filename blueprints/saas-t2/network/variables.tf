variable "project" {
  description = "Nombre del proyecto (cliente); prefijo de los nombres de recursos y de las rutas SSM."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}$", var.project))
    error_message = "project debe ser minúsculas, dígitos y guiones (2-21 caracteres), empezando por letra."
  }

  nullable = false
}

variable "environment" {
  description = "Entorno de despliegue."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment debe ser uno de: dev, staging, prod."
  }

  nullable = false
}

variable "cidr_block" {
  description = "CIDR de la VPC (entre /16 y /20). Reserva rangos distintos por entorno si algún día se interconectan."
  type        = string
  default     = "10.20.0.0/16"
  nullable    = false
}

variable "az_names" {
  description = "Zonas de disponibilidad (2 o 3), explícitas. El ALB exige al menos 2; Fargate en 2 AZ no cuesta más."
  type        = list(string)
  nullable    = false
}

variable "interface_endpoints" {
  description = "Servicios con endpoint de interfaz (cada uno cuesta ~0,01 USD/h por AZ). Los de por defecto permiten descargar imágenes de ECR, escribir logs, leer secretos y rotarlos sin pasar por la NAT."
  type        = list(string)
  default     = ["ecr.api", "ecr.dkr", "logs", "secretsmanager", "sts", "kms"]
  nullable    = false
}

variable "alarm_emails" {
  description = "Correos suscritos al topic de alarmas del entorno (lo comparten todas las capas). Deben confirmar la suscripción. En prod, al menos uno."
  type        = list(string)
  default     = []

  validation {
    condition     = var.environment != "prod" || length(var.alarm_emails) > 0
    error_message = "En prod indica al menos un correo en alarm_emails: unas alarmas que nadie recibe no sirven."
  }

  nullable = false
}

variable "tags" {
  description = "Etiquetas adicionales para los recursos (las obligatorias van en default_tags del provider, en live/)."
  type        = map(string)
  default     = {}
  nullable    = false
}
