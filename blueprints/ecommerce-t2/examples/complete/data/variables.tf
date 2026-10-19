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
