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
  description = "Prefijo de las alarmas y nombre del topic. Si es null: <project>-<environment>."
  type        = string
  default     = null

  validation {
    condition     = var.name == null || can(regex("^[a-z][a-z0-9-]{1,40}$", var.name))
    error_message = "name debe ser minúsculas, dígitos y guiones (2-41 caracteres), empezando por letra."
  }
}

variable "kms_key_arn" {
  description = "ARN de la CMK que cifra el topic de SNS. Su política debe autorizar a los servicios que publican (cloudwatch.amazonaws.com y los de publisher_service_principals) con kms:GenerateDataKey* y kms:Decrypt: usa service_principals en foundation/kms-key. Con una clave sin ese permiso las alarmas no pueden notificar."
  type        = string

  validation {
    condition     = can(regex("^arn:[a-z-]+:kms:[a-z0-9-]+:[0-9]{12}:key/", var.kms_key_arn))
    error_message = "kms_key_arn debe ser el ARN de una clave KMS (no un alias)."
  }

  nullable = false
}

variable "email_subscriptions" {
  description = "Correos suscritos al topic. Cada destinatario debe confirmar la suscripción desde el mensaje que recibe de AWS; hasta entonces no recibe alarmas."
  type        = list(string)
  default     = []
  nullable    = false

  validation {
    condition     = alltrue([for e in var.email_subscriptions : can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", e))])
    error_message = "Cada suscripción debe ser una dirección de correo válida."
  }

  validation {
    condition     = var.environment != "prod" || length(var.email_subscriptions) > 0 || var.existing_topic_arn != null
    error_message = "En prod hay que indicar al menos un correo: unas alarmas que nadie recibe no sirven."
  }

  validation {
    condition     = var.existing_topic_arn == null || length(var.email_subscriptions) == 0
    error_message = "Con existing_topic_arn las suscripciones se gestionan donde se creó el topic: deja email_subscriptions vacío."
  }
}

variable "existing_topic_arn" {
  description = "Topic SNS ya existente (cifrado) al que envían las alarmas, p. ej. el que crea la capa network de un blueprint para todo el entorno. null = el módulo crea su propio topic con kms_key_arn y las suscripciones."
  type        = string
  default     = null

  validation {
    condition     = var.existing_topic_arn == null || can(regex("^arn:aws[a-z-]*:sns:[a-z0-9-]+:[0-9]{12}:[A-Za-z0-9_-]{1,256}$", var.existing_topic_arn))
    error_message = "existing_topic_arn debe ser el ARN de un topic SNS."
  }
}

variable "publisher_service_principals" {
  description = "Servicios autorizados a publicar en el topic (con aws:SourceAccount). CloudWatch siempre; añade events.amazonaws.com o backup.amazonaws.com si otras reglas del entorno usan este topic."
  type        = list(string)
  default     = ["cloudwatch.amazonaws.com"]
  nullable    = false

  validation {
    condition     = contains(var.publisher_service_principals, "cloudwatch.amazonaws.com")
    error_message = "publisher_service_principals debe incluir cloudwatch.amazonaws.com."
  }
}

variable "alb" {
  description = "ALB a vigilar, por clave estable: alb_arn_suffix (app/<nombre>/<id>) y target_group_arn_suffix (targetgroup/<nombre>/<id>), salidas de compute/alb-internal."
  type = map(object({
    alb_arn_suffix          = string
    target_group_arn_suffix = string
  }))
  default  = {}
  nullable = false
}

variable "ecs_services" {
  description = "Servicios ECS, por clave estable: nombre del cluster, del servicio y mínimo de tareas en ejecución (Container Insights debe estar activado en el cluster)."
  type = map(object({
    cluster_name      = string
    service_name      = string
    min_running_tasks = optional(number, 1)
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for s in values(var.ecs_services) : s.min_running_tasks >= 1])
    error_message = "min_running_tasks debe ser al menos 1."
  }
}

variable "aurora_clusters" {
  description = "Clusters Aurora, por clave estable: cluster_id y has_replicas (activa la alarma de retraso de réplica)."
  type = map(object({
    cluster_id   = string
    has_replicas = optional(bool, false)
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
  description = "Replication groups de ElastiCache, por clave estable: replication_group_id y node_count (num_cache_clusters; los nodos se llaman <id>-001, <id>-002...). Se crea una alarma por nodo."
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
  description = "Tablas DynamoDB, por clave estable: table_name y las operaciones sumadas en las alarmas (ThrottledRequests y SystemErrors solo existen por operación)."
  type = map(object({
    table_name = string
    operations = optional(list(string), ["GetItem", "PutItem", "UpdateItem", "DeleteItem", "Query", "Scan", "BatchGetItem", "BatchWriteItem"])
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for t in values(var.dynamodb_tables) : length(t.operations) >= 1 && length(t.operations) <= 20])
    error_message = "operations debe tener entre 1 y 20 operaciones."
  }
}

variable "lambda_functions" {
  description = "Funciones Lambda, por clave estable: function_name y timeout_seconds (la alarma de duración p95 salta al superar el porcentaje thresholds.lambda_duration_p95_ratio del timeout)."
  type = map(object({
    function_name   = string
    timeout_seconds = optional(number, 30)
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for f in values(var.lambda_functions) : f.timeout_seconds >= 1 && f.timeout_seconds <= 900])
    error_message = "timeout_seconds debe estar entre 1 y 900."
  }
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

variable "waf_web_acls" {
  description = "Web ACL de WAF con alarma de BlockedRequests anómalo (banda de detección de anomalías), por clave estable: web_acl_name y region_dimension (la región del ACL regional, o Global para scope CLOUDFRONT; las métricas de CloudFront/WAF global solo existen en us-east-1, así que instancia el módulo en esa región para ellos)."
  type = map(object({
    web_acl_name     = string
    region_dimension = optional(string, "Global")
  }))
  default  = {}
  nullable = false
}

variable "cloudfront_distributions" {
  description = "Distribuciones de CloudFront con alarma de 5xxErrorRate, por clave estable: distribution_id. Sus métricas solo existen en us-east-1: instancia el módulo en esa región (con su propio topic) para ellas."
  type = map(object({
    distribution_id = string
  }))
  default  = {}
  nullable = false
}

variable "thresholds" {
  description = "Umbrales y ventanas de evaluación. Los valores por defecto son un punto de partida: ajústalos al tamaño real de cada servicio (p. ej. db_connections según la clase de instancia)."
  type = object({
    period_seconds                  = optional(number, 300)
    evaluation_periods              = optional(number, 3)
    datapoints_to_alarm             = optional(number, 2)
    alb_target_5xx_count            = optional(number, 10)
    alb_response_time_p99_seconds   = optional(number, 2)
    alb_unhealthy_hosts             = optional(number, 1)
    ecs_cpu_percent                 = optional(number, 85)
    ecs_memory_percent              = optional(number, 85)
    db_cpu_percent                  = optional(number, 80)
    db_freeable_memory_bytes        = optional(number, 268435456)
    db_connections                  = optional(number, 400)
    aurora_replica_lag_milliseconds = optional(number, 1000)
    rds_free_storage_bytes          = optional(number, 10737418240)
    cache_engine_cpu_percent        = optional(number, 80)
    cache_memory_percent            = optional(number, 80)
    cache_evictions                 = optional(number, 100)
    dynamodb_throttled_requests     = optional(number, 5)
    dynamodb_system_errors          = optional(number, 1)
    lambda_errors                   = optional(number, 1)
    lambda_throttles                = optional(number, 1)
    lambda_duration_p95_ratio       = optional(number, 0.8)
    api_5xx_count                   = optional(number, 5)
    api_latency_p95_milliseconds    = optional(number, 1500)
    waf_anomaly_band_width          = optional(number, 4)
    cloudfront_5xx_percent          = optional(number, 5)
  })
  default  = {}
  nullable = false

  validation {
    condition     = var.thresholds.period_seconds >= 60 && var.thresholds.period_seconds % 60 == 0
    error_message = "period_seconds debe ser múltiplo de 60 y al menos 60."
  }

  validation {
    condition     = var.thresholds.evaluation_periods >= 1 && var.thresholds.datapoints_to_alarm >= 1 && var.thresholds.datapoints_to_alarm <= var.thresholds.evaluation_periods
    error_message = "datapoints_to_alarm debe estar entre 1 y evaluation_periods."
  }

  validation {
    condition     = var.thresholds.lambda_duration_p95_ratio > 0 && var.thresholds.lambda_duration_p95_ratio <= 1
    error_message = "lambda_duration_p95_ratio debe estar entre 0 (exclusivo) y 1."
  }
}

variable "tags" {
  description = "Etiquetas adicionales."
  type        = map(string)
  default     = {}
  nullable    = false
}
