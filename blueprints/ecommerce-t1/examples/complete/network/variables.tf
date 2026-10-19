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
  default     = "t1"
  nullable    = false
}

variable "run_id" {
  description = "Identificador de la ejecución (etiqueta RunId para encontrar restos)."
  type        = string
  default     = "manual"
  nullable    = false
}

variable "alarm_emails" {
  description = "Correos de las alarmas (opcional en dev)."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "nat_mode" {
  description = "NAT de la prueba: null = la de dev (zonal_single); regional para probar la NAT regional."
  type        = string
  default     = null
}
