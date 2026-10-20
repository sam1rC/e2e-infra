variable "region" {
  description = "Región de la aplicación."
  type        = string
  default     = "us-east-1"
  nullable    = false
}

variable "account_id" {
  description = "Cuenta sandbox permitida (allowed_account_ids evita aplicar en otra cuenta)."
  type        = string
  nullable    = false
}

variable "name_suffix" {
  description = "Sufijo del proyecto (ct-<sufijo>) para que las pruebas no colisionen; el mismo en todas las capas."
  type        = string
  default     = "t2"
  nullable    = false
}

variable "run_id" {
  description = "Identificador de la ejecución (etiqueta RunId para encontrar restos)."
  type        = string
  default     = "manual"
  nullable    = false
}

variable "domain_name" {
  description = "Dominio de prueba (subdominio de la zona delegada en la sandbox)."
  type        = string
  nullable    = false
}

variable "zone_id" {
  description = "Zona de Route 53 de la sandbox que contiene domain_name."
  type        = string
  nullable    = false
}

variable "image" {
  description = "Imagen de la aplicación por digest. Con NAT vale una pública que escuche en 8080 sin root, p. ej. public.ecr.aws/nginx/nginx-unprivileged@sha256:<digest multi-arquitectura>."
  type        = string
  nullable    = false
}

variable "command" {
  description = "Comando del contenedor de prueba (null = el de la imagen). Con un servidor que no escribe en disco basta el FS de solo lectura, p. ej. [\"python\", \"-m\", \"http.server\", \"8080\"]."
  type        = list(string)
  default     = null
}
