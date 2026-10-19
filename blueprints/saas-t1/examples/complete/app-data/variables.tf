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
  default     = "s1"
  nullable    = false
}

variable "run_id" {
  description = "Identificador de la ejecución (etiqueta RunId para encontrar restos)."
  type        = string
  default     = "manual"
  nullable    = false
}

variable "dr_region" {
  description = "Región de DR de las copias de backup."
  type        = string
  default     = "us-west-2"
  nullable    = false
}

variable "cache_enabled" {
  description = "Crea Valkey (1 nodo cache.t4g.micro en dev)."
  type        = bool
  default     = true
  nullable    = false
}

variable "dr_copy" {
  description = "Copia de backups a la región de DR (oleada de resiliencia de la campaña)."
  type        = bool
  default     = false
  nullable    = false
}
