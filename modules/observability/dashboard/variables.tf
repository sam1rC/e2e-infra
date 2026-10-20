variable "project" {
  description = "Nombre del proyecto; prefijo de los nombres de recursos."
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

variable "name" {
  description = "Nombre del dashboard (uno por blueprint, p. ej. acme-prod-ecommerce-t1). Si es null: <project>-<environment>."
  type        = string
  default     = null

  validation {
    condition     = var.name == null || can(regex("^[A-Za-z0-9_-]{1,255}$", var.name))
    error_message = "name solo admite letras, dígitos, guiones y guiones bajos (hasta 255 caracteres)."
  }
}

variable "period_seconds" {
  description = "Resolución de las series, en segundos (múltiplo de 60)."
  type        = number
  default     = 300

  validation {
    condition     = var.period_seconds >= 60 && var.period_seconds % 60 == 0
    error_message = "period_seconds debe ser múltiplo de 60 y al menos 60."
  }

  nullable = false
}

variable "alarm_arns" {
  description = "ARN de las alarmas que muestra el widget de estado (salida alarm_arns de observability/alarms)."
  type        = map(string)
  default     = {}
  nullable    = false
}

variable "application_signals" {
  description = "Servicio con CloudWatch Application Signals (alimentado por el sidecar ADOT de ecs-service): service_name y environment_name tal como aparecen en Application Signals. Añade widgets de latencia, fallos, errores y disponibilidad. null = sin ellos. Los SLO no los crea este módulo (el provider no tiene recurso): ver el README."
  type = object({
    service_name     = string
    environment_name = string
  })
  default = null
}

variable "alb" {
  description = "ALB, por clave estable: alb_arn_suffix y target_group_arn_suffix."
  type = map(object({
    alb_arn_suffix          = string
    target_group_arn_suffix = string
  }))
  default  = {}
  nullable = false
}

variable "ecs_services" {
  description = "Servicios ECS, por clave estable: cluster_name y service_name."
  type = map(object({
    cluster_name = string
    service_name = string
  }))
  default  = {}
  nullable = false
}

variable "aurora_clusters" {
  description = "Clusters Aurora, por clave estable: cluster_id."
  type = map(object({
    cluster_id = string
  }))
  default  = {}
  nullable = false
}

variable "rds_instances" {
  description = "Instancias RDS, por clave estable: instance_id."
  type = map(object({
    instance_id = string
  }))
  default  = {}
  nullable = false
}

variable "elasticache" {
  description = "Replication groups de ElastiCache, por clave estable: replication_group_id y node_count (los nodos se llaman <id>-001, <id>-002...)."
  type = map(object({
    replication_group_id = string
    node_count           = optional(number, 1)
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for g in values(var.elasticache) : g.node_count >= 1 && g.node_count <= 6])
    error_message = "node_count debe estar entre 1 y 6."
  }
}

variable "dynamodb_tables" {
  description = "Tablas DynamoDB, por clave estable: table_name."
  type = map(object({
    table_name = string
  }))
  default  = {}
  nullable = false
}

variable "lambda_functions" {
  description = "Funciones Lambda, por clave estable: function_name."
  type = map(object({
    function_name = string
  }))
  default  = {}
  nullable = false
}

variable "rest_apis" {
  description = "APIs REST de API Gateway, por clave estable: api_name y stage."
  type = map(object({
    api_name = string
    stage    = string
  }))
  default  = {}
  nullable = false
}

variable "http_apis" {
  description = "APIs HTTP de API Gateway, por clave estable: api_id y stage ($default si no se nombra)."
  type = map(object({
    api_id = string
    stage  = optional(string, "$default")
  }))
  default  = {}
  nullable = false
}

variable "cloudfront_distributions" {
  description = "Distribuciones de CloudFront, por clave estable: distribution_id (sus métricas están en us-east-1; el widget lo indica y el dashboard puede estar en cualquier región)."
  type = map(object({
    distribution_id = string
  }))
  default  = {}
  nullable = false
}

variable "waf_web_acls" {
  description = "Web ACL de WAF, por clave estable: web_acl_name y region_dimension (Global para scope CLOUDFRONT, que vive en us-east-1; la región del ACL si es regional)."
  type = map(object({
    web_acl_name     = string
    region_dimension = optional(string, "Global")
  }))
  default  = {}
  nullable = false
}
