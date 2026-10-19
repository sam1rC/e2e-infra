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


variable "domain_name" {
  description = "Dominio público de la tienda: el ALB lleva su certificado regional (CloudFront reenvía el Host, ADR 0007) y solo enruta peticiones con ese Host."
  type        = string

  validation {
    condition     = can(regex("^([a-z0-9]([a-z0-9-]*[a-z0-9])?\\.)+[a-z]{2,}$", var.domain_name))
    error_message = "domain_name debe ser un nombre DNS válido en minúsculas."
  }

  nullable = false
}

variable "zone_id" {
  description = "Zona de Route 53 donde se valida el certificado regional del ALB. null = DNS externo (alb_certificate_arn obligatorio)."
  type        = string
  default     = null
}

variable "alb_certificate_arn" {
  description = "Certificado ACM ya emitido en la región de la aplicación para domain_name. null = el blueprint lo emite en zone_id."
  type        = string
  default     = null

  validation {
    condition     = var.alb_certificate_arn != null || var.zone_id != null
    error_message = "Indica zone_id (el blueprint emite el certificado) o alb_certificate_arn."
  }
}

variable "service" {
  description = "Servicio de la aplicación en Fargate: image por digest (en ECR o en un registro alcanzable por la NAT), command (null = el de la imagen), puerto, tamaño, ruta del health check del ALB, variables no secretas y escalado (min_tasks null = 2 en prod y 1 en el resto). app_deploys_outside_iac = true si el pipeline de la app publica las revisiones (decídelo al adoptar el blueprint: cambiarlo recrea el servicio). volume_permissions_image: imagen con chown (p. ej. busybox, por digest en ECR privado) para que el usuario no root de la aplicación pueda escribir en /tmp (Fargate monta los volúmenes como root)."
  type = object({
    image                    = string
    command                  = optional(list(string))
    container_port           = optional(number, 8080)
    cpu                      = optional(number, 512)
    memory                   = optional(number, 1024)
    cpu_architecture         = optional(string, "ARM64")
    health_check_path        = optional(string, "/healthz")
    environment_variables    = optional(map(string), {})
    min_tasks                = optional(number)
    max_tasks                = optional(number, 4)
    app_deploys_outside_iac  = optional(bool, false)
    volume_permissions_image = optional(string)
  })
  nullable = false
}

variable "allow_internet_egress" {
  description = "Permite a las tareas HTTPS (443) saliente a Internet por la NAT: actívalo si la aplicación llama a APIs externas (pasarela de pagos, correo transaccional...) o descarga imágenes de registros públicos. false (por defecto) = solo endpoints de VPC, S3 y bases de datos."
  type        = bool
  default     = false
  nullable    = false
}

variable "extra_task_role_policies" {
  description = "Políticas JSON adicionales del task role (identidad de la aplicación), por nombre estable, con acciones y recursos explícitos. Las usan los blueprints SaaS que envuelven esta capa."
  type        = map(string)
  default     = {}
  nullable    = false
}

variable "tags" {
  description = "Etiquetas adicionales para los recursos (las obligatorias van en default_tags del provider, en live/)."
  type        = map(string)
  default     = {}
  nullable    = false
}
