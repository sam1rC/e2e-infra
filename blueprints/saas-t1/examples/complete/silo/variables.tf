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

variable "deploy_trusted_role_arns" {
  description = "Rol de apply del CI del control plane (otra cuenta)."
  type        = list(string)
  default     = ["arn:aws:iam::111111111111:role/gha-apply-prod"]
  nullable    = false
}

variable "permissions_boundary_arn" {
  description = "Permissions boundary del rol de despliegue."
  type        = string
  default     = "arn:aws:iam::111111111111:policy/deploy-boundary"
  nullable    = false
}

variable "budget_emails" {
  description = "Correos del presupuesto del tenant."
  type        = list(string)
  default     = ["billing@example.com"]
  nullable    = false
}

variable "existing_anomaly_monitor_arn" {
  description = "Monitor de anomalías existente (Default-Services-Monitor en cuentas nuevas)."
  type        = string
  default     = null
}
