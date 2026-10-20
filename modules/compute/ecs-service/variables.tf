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
  description = "Entorno de despliegue. En prod: mínimo 2 tareas y deployment_minimum_healthy_percent = 100."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment debe ser uno de: dev, staging, prod."
  }

  nullable = false
}

variable "name" {
  description = "Nombre del servicio; el servicio, la task definition y los roles se llaman <project>-<environment>-<name>."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,30}[a-z0-9])?$", var.name))
    error_message = "name debe tener 1-32 caracteres: minúsculas, dígitos y guiones, sin guion al principio ni al final."
  }

  nullable = false
}

variable "cluster_arn" {
  description = "ARN del cluster ECS (módulo ecs-cluster)."
  type        = string

  validation {
    condition     = can(regex("^arn:[a-z-]+:ecs:[a-z0-9-]+:[0-9]{12}:cluster/[a-zA-Z0-9_-]+$", var.cluster_arn))
    error_message = "cluster_arn debe ser el ARN de un cluster de ECS."
  }

  nullable = false
}

variable "vpc_id" {
  description = "ID de la VPC del servicio."
  type        = string

  validation {
    condition     = can(regex("^vpc-[0-9a-f]+$", var.vpc_id))
    error_message = "vpc_id debe tener el formato vpc-xxxxxxxx."
  }

  nullable = false
}

variable "subnet_ids" {
  description = "Subredes de la capa app (privadas) donde corren las tareas, en al menos 2 AZ en prod. Las tareas nunca reciben IP pública."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 1 && alltrue([for s in var.subnet_ids : can(regex("^subnet-[0-9a-f]+$", s))])
    error_message = "Indica al menos una subred con el formato subnet-xxxxxxxx."
  }

  validation {
    condition     = var.environment != "prod" || length(var.subnet_ids) >= 2
    error_message = "En prod las tareas deben repartirse en al menos 2 subredes (AZ)."
  }

  nullable = false
}

variable "image" {
  description = "Imagen del contenedor referenciada por DIGEST (<repo>@sha256:<64 hex>), nunca por etiqueta mutable."
  type        = string

  validation {
    condition     = can(regex("@sha256:[0-9a-f]{64}$", var.image))
    error_message = "image debe referenciarse por digest: <repositorio>@sha256:<64 caracteres hexadecimales>."
  }

  nullable = false
}

variable "container_name" {
  description = "Nombre del contenedor de la aplicación. Si es null: el name del servicio."
  type        = string
  default     = null

  validation {
    condition     = var.container_name == null || can(regex("^[a-zA-Z0-9][a-zA-Z0-9_-]{0,254}$", var.container_name))
    error_message = "container_name solo admite letras, dígitos, guiones y guiones bajos."
  }
}

variable "container_port" {
  description = "Puerto en el que escucha la aplicación (target group y regla de entrada del SG)."
  type        = number
  default     = 8080

  validation {
    condition     = var.container_port >= 1 && var.container_port <= 65535
    error_message = "container_port debe estar entre 1 y 65535."
  }

  nullable = false
}

variable "command" {
  description = "Comando del contenedor (sustituye al CMD de la imagen). null = el de la imagen."
  type        = list(string)
  default     = null
}

variable "user" {
  description = "Usuario con el que corre el contenedor (uid[:gid]). No puede ser root."
  type        = string
  default     = "10001:10001"

  validation {
    condition     = !contains(["0", "root", "0:0", "root:root"], var.user) && !startswith(var.user, "0:") && !startswith(var.user, "root:")
    error_message = "El contenedor no puede correr como root: indica un uid distinto de 0."
  }

  nullable = false
}

variable "writable_paths" {
  description = "Rutas absolutas escribibles (volúmenes efímeros): el sistema de archivos raíz es de solo lectura. Por defecto /tmp."
  type        = list(string)
  default     = ["/tmp"]
  nullable    = false

  validation {
    condition     = alltrue([for p in var.writable_paths : can(regex("^/[a-zA-Z0-9._/-]+$", p)) && p != "/"])
    error_message = "Cada ruta escribible debe ser absoluta y distinta de /."
  }
}

variable "environment_variables" {
  description = "Variables de entorno NO secretas del contenedor. Los secretos van en secrets."
  type        = map(string)
  default     = {}
  nullable    = false
}

variable "secrets" {
  description = "Secretos inyectados como variables de entorno: nombre → ARN de Secrets Manager (admite sufijo :clave-json::) o de un parámetro SSM. El execution role solo recibe permiso sobre estos ARNs."
  type        = map(string)
  default     = {}
  nullable    = false

  validation {
    condition = alltrue([
      for v in values(var.secrets) :
      can(regex("^arn:[a-z-]+:secretsmanager:[a-z0-9-]+:[0-9]{12}:secret:[^:]+", v)) ||
      can(regex("^arn:[a-z-]+:ssm:[a-z0-9-]+:[0-9]{12}:parameter/.+", v))
    ])
    error_message = "Cada secreto debe ser el ARN de un secreto de Secrets Manager o de un parámetro de SSM."
  }
}

variable "secrets_kms_key_arns" {
  description = "CMKs que cifran los secretos/parámetros de secrets: el execution role recibe kms:Decrypt sobre ellas solo vía Secrets Manager/SSM (kms:ViaService)."
  type        = list(string)
  default     = []
  nullable    = false

  validation {
    condition     = alltrue([for k in var.secrets_kms_key_arns : can(regex("^arn:[a-z-]+:kms:[a-z0-9-]+:[0-9]{12}:key/", k))])
    error_message = "secrets_kms_key_arns debe contener ARNs de claves KMS (no alias)."
  }
}

variable "cpu" {
  description = "CPU de la tarea Fargate en unidades (256, 512, 1024, 2048, 4096, 8192 o 16384)."
  type        = number
  default     = 512

  validation {
    condition     = contains([256, 512, 1024, 2048, 4096, 8192, 16384], var.cpu)
    error_message = "cpu debe ser 256, 512, 1024, 2048, 4096, 8192 o 16384."
  }

  nullable = false
}

variable "memory" {
  description = "Memoria de la tarea Fargate en MiB (debe ser una combinación válida con cpu)."
  type        = number
  default     = 1024

  validation {
    condition     = var.memory >= 512 && var.memory <= 122880
    error_message = "memory debe estar entre 512 y 122880 MiB."
  }

  validation {
    condition = (
      (var.cpu == 256 && contains([512, 1024, 2048], var.memory)) ||
      (var.cpu == 512 && var.memory >= 1024 && var.memory <= 4096) ||
      (var.cpu == 1024 && var.memory >= 2048 && var.memory <= 8192) ||
      (var.cpu == 2048 && var.memory >= 4096 && var.memory <= 16384) ||
      (var.cpu == 4096 && var.memory >= 8192 && var.memory <= 30720) ||
      (var.cpu == 8192 && var.memory >= 16384 && var.memory <= 61440) ||
      (var.cpu == 16384 && var.memory >= 32768 && var.memory <= 122880)
    )
    error_message = "La combinación cpu/memory no es válida en Fargate (p. ej. 512 CPU admite 1024-4096 MiB)."
  }

  nullable = false
}

variable "cpu_architecture" {
  description = "Arquitectura de CPU de la tarea: ARM64 (Graviton, por defecto) o X86_64. La imagen debe construirse para la misma arquitectura."
  type        = string
  default     = "ARM64"

  validation {
    condition     = contains(["ARM64", "X86_64"], var.cpu_architecture)
    error_message = "cpu_architecture debe ser ARM64 o X86_64."
  }

  nullable = false
}

variable "container_health_check" {
  description = "Health check del contenedor (opcional; el del target group ya vigila el servicio). command p. ej. [\"CMD-SHELL\", \"curl -f http://localhost:8080/healthz || exit 1\"]."
  type = object({
    command      = list(string)
    interval     = optional(number, 30)
    timeout      = optional(number, 5)
    retries      = optional(number, 3)
    start_period = optional(number, 0)
  })
  default = null
}

variable "ecr_repository_arns" {
  description = "ARNs de repositorios ECR adicionales desde los que el execution role puede descargar imágenes. Los de image y otel_image se deducen solos si son de ECR."
  type        = list(string)
  default     = []
  nullable    = false

  validation {
    condition     = alltrue([for a in var.ecr_repository_arns : can(regex("^arn:[a-z-]+:ecr:[a-z0-9-]+:[0-9]{12}:repository/", a))])
    error_message = "ecr_repository_arns debe contener ARNs de repositorios ECR."
  }
}

variable "log_kms_key_arn" {
  description = "CMK que cifra el log group del servicio. Su política debe autorizar a logs.<región>.amazonaws.com."
  type        = string

  validation {
    condition     = can(regex("^arn:[a-z-]+:kms:[a-z0-9-]+:[0-9]{12}:key/", var.log_kms_key_arn))
    error_message = "log_kms_key_arn debe ser el ARN de una clave KMS (no un alias)."
  }

  nullable = false
}

variable "log_retention_days" {
  description = "Retención del log group, en días (valores admitidos por CloudWatch Logs). En prod, al menos 90."
  type        = number
  default     = 90

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "log_retention_days debe ser un valor admitido por CloudWatch Logs (1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, ...)."
  }

  validation {
    condition     = var.environment != "prod" || var.log_retention_days >= 90
    error_message = "En prod la retención de logs debe ser de al menos 90 días."
  }

  nullable = false
}

variable "alb_security_group_id" {
  description = "Security group del ALB: único origen permitido de la entrada al puerto del contenedor. null = el servicio no recibe tráfico (workers)."
  type        = string
  default     = null

  validation {
    condition     = var.alb_security_group_id == null || can(regex("^sg-[0-9a-f]+$", var.alb_security_group_id))
    error_message = "alb_security_group_id debe tener el formato sg-xxxxxxxx."
  }
}

variable "target_group_arn" {
  description = "ARN del target group (tipo ip) del ALB al que se registran las tareas. null = sin balanceador."
  type        = string
  default     = null

  validation {
    condition     = var.target_group_arn == null || can(regex("^arn:[a-z-]+:elasticloadbalancing:[a-z0-9-]+:[0-9]{12}:targetgroup/", var.target_group_arn))
    error_message = "target_group_arn debe ser el ARN de un target group."
  }
}

variable "alb_enabled" {
  description = "El servicio recibe tráfico de un ALB (registro en target_group_arn y entrada desde alb_security_group_id). Indícalo (true) cuando el ALB se crea en el mismo apply: OpenTofu necesita conocer al planificar si se crea la regla de entrada. null = activado si target_group_arn no es null."
  type        = bool
  default     = null

  validation {
    condition     = var.alb_enabled != true || (var.target_group_arn != null && var.alb_security_group_id != null)
    error_message = "alb_enabled = true requiere target_group_arn y alb_security_group_id."
  }
}

variable "health_check_grace_period_seconds" {
  description = "Segundos que ECS ignora los health checks del balanceador tras arrancar una tarea. Solo aplica con target_group_arn."
  type        = number
  default     = 60

  validation {
    condition     = var.health_check_grace_period_seconds >= 0 && var.health_check_grace_period_seconds <= 2147483647
    error_message = "health_check_grace_period_seconds debe ser un entero no negativo."
  }

  nullable = false
}

variable "egress_rules" {
  description = "Salida del SG de las tareas, por clave estable. Sin reglas, las tareas no salen a ninguna parte: añade los endpoints de VPC (ECR api/dkr, logs, secretsmanager, xray; SG o prefix list del gateway de S3), la base de datos, etc. Cada regla indica exactamente un destino: security_group_id, prefix_list_id o cidr_ipv4."
  type = map(object({
    description       = string
    port              = number
    protocol          = optional(string, "tcp")
    security_group_id = optional(string)
    prefix_list_id    = optional(string)
    cidr_ipv4         = optional(string)
  }))
  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for r in values(var.egress_rules) :
      length([for d in [r.security_group_id, r.prefix_list_id, r.cidr_ipv4] : d if d != null]) == 1
    ])
    error_message = "Cada regla de salida necesita exactamente un destino: security_group_id, prefix_list_id o cidr_ipv4."
  }

  validation {
    condition     = alltrue([for r in values(var.egress_rules) : r.port >= 1 && r.port <= 65535 && contains(["tcp", "udp"], r.protocol)])
    error_message = "Cada regla de salida necesita un puerto 1-65535 y protocolo tcp o udp."
  }

  validation {
    condition     = alltrue([for r in values(var.egress_rules) : r.cidr_ipv4 == null || can(cidrhost(r.cidr_ipv4, 0))])
    error_message = "cidr_ipv4 debe ser un CIDR IPv4 válido."
  }
}

variable "task_role_policies" {
  description = "Políticas JSON en línea del task role (el rol de la aplicación), por nombre estable. Vacío por defecto: la aplicación no tiene permisos AWS salvo los que se inyecten aquí (con acciones y recursos explícitos)."
  type        = map(string)
  default     = {}
  nullable    = false
}

variable "permissions_boundary_arn" {
  description = "ARN de una permissions boundary para el execution role y el task role. null = ninguna."
  type        = string
  default     = null

  validation {
    condition     = var.permissions_boundary_arn == null || can(regex("^arn:[a-z-]+:iam::[0-9]{12}:policy/", var.permissions_boundary_arn))
    error_message = "permissions_boundary_arn debe ser el ARN de una política IAM."
  }
}

variable "enable_exec" {
  description = "Activa ECS Exec en el servicio (el cluster debe tener el registro cifrado; ver ecs-cluster). Añade al task role los permisos ssmmessages necesarios. Desaconsejado en prod."
  type        = bool
  default     = false
  nullable    = false
}

variable "desired_count" {
  description = "Número inicial de tareas. null = min_tasks. Después lo gobierna el autoscaling (el módulo ignora cambios posteriores de desired_count)."
  type        = number
  default     = null

  validation {
    condition     = var.desired_count == null || var.desired_count >= 0
    error_message = "desired_count no puede ser negativo."
  }
}

variable "min_tasks" {
  description = "Mínimo de tareas del autoscaling. null = 2 en prod (una por AZ) y 1 en el resto."
  type        = number
  default     = null

  validation {
    condition     = var.min_tasks == null || var.min_tasks >= 1
    error_message = "min_tasks debe ser al menos 1."
  }

  validation {
    condition     = var.environment != "prod" || var.min_tasks == null || var.min_tasks >= 2
    error_message = "En prod min_tasks debe ser al menos 2 (una tarea por AZ)."
  }
}

variable "max_tasks" {
  description = "Máximo de tareas del autoscaling."
  type        = number
  default     = 4

  validation {
    condition     = var.max_tasks >= 1 && var.max_tasks >= coalesce(var.min_tasks, var.environment == "prod" ? 2 : 1)
    error_message = "max_tasks debe ser al menos min_tasks."
  }

  nullable = false
}

variable "cpu_target_percent" {
  description = "Objetivo de CPU media (%) del target tracking."
  type        = number
  default     = 60

  validation {
    condition     = var.cpu_target_percent >= 10 && var.cpu_target_percent <= 90
    error_message = "cpu_target_percent debe estar entre 10 y 90."
  }

  nullable = false
}

variable "requests_per_target" {
  description = "Objetivo de ALBRequestCountPerTarget del segundo target tracking. null = solo CPU. Exige alb_arn_suffix y target_group_arn_suffix."
  type        = number
  default     = null

  validation {
    condition     = var.requests_per_target == null || var.requests_per_target >= 1
    error_message = "requests_per_target debe ser al menos 1."
  }

  validation {
    condition     = var.requests_per_target == null || (var.alb_arn_suffix != null && var.target_group_arn_suffix != null)
    error_message = "requests_per_target requiere alb_arn_suffix y target_group_arn_suffix."
  }
}

variable "alb_arn_suffix" {
  description = "Sufijo del ARN del ALB (output alb_arn_suffix de alb-internal); solo para el autoscaling por solicitudes."
  type        = string
  default     = null
}

variable "target_group_arn_suffix" {
  description = "Sufijo del ARN del target group (output target_group_arn_suffixes de alb-internal); solo para el autoscaling por solicitudes."
  type        = string
  default     = null
}

variable "scale_in_cooldown_seconds" {
  description = "Enfriamiento tras reducir tareas."
  type        = number
  default     = 300
  nullable    = false
}

variable "scale_out_cooldown_seconds" {
  description = "Enfriamiento tras aumentar tareas."
  type        = number
  default     = 60
  nullable    = false
}

variable "deployment_minimum_healthy_percent" {
  description = "Porcentaje mínimo de tareas sanas durante un despliegue. null = 100 en prod y 50 en el resto. En prod no puede ser menor que 100."
  type        = number
  default     = null

  validation {
    condition     = var.deployment_minimum_healthy_percent == null || (var.deployment_minimum_healthy_percent >= 0 && var.deployment_minimum_healthy_percent <= 100)
    error_message = "deployment_minimum_healthy_percent debe estar entre 0 y 100."
  }

  validation {
    condition     = var.environment != "prod" || coalesce(var.deployment_minimum_healthy_percent, 100) == 100
    error_message = "En prod deployment_minimum_healthy_percent debe ser 100."
  }
}

variable "deployment_maximum_percent" {
  description = "Porcentaje máximo de tareas durante un despliegue."
  type        = number
  default     = 200

  validation {
    condition     = var.deployment_maximum_percent >= 100 && var.deployment_maximum_percent <= 400
    error_message = "deployment_maximum_percent debe estar entre 100 y 400."
  }

  nullable = false
}

variable "app_deploys_outside_iac" {
  description = "true si el pipeline de la aplicación despliega versiones nuevas (aws ecs update-service): OpenTofu deja de gestionar task_definition. Cambiar este valor recrea el servicio (la dirección del recurso cambia); decídelo al adoptar el módulo."
  type        = bool
  default     = false
  nullable    = false
}

variable "enable_otel_sidecar" {
  description = "Añade el collector AWS Distro for OpenTelemetry (ADOT) como sidecar: trazas OTLP a X-Ray/CloudWatch Application Signals y métricas a CloudWatch. NO uses los SDK ni el daemon de X-Ray (fin de soporte el 25-feb-2027)."
  type        = bool
  default     = false
  nullable    = false
}

variable "otel_image" {
  description = "Imagen del collector ADOT por DIGEST, copiada a tu ECR privado (public.ecr.aws no es alcanzable sin NAT). Obligatoria con enable_otel_sidecar."
  type        = string
  default     = null

  validation {
    condition     = var.otel_image == null || can(regex("@sha256:[0-9a-f]{64}$", var.otel_image))
    error_message = "otel_image debe referenciarse por digest: <repositorio>@sha256:<64 caracteres hexadecimales>."
  }

  validation {
    condition     = !var.enable_otel_sidecar || var.otel_image != null
    error_message = "enable_otel_sidecar requiere otel_image."
  }
}

variable "volume_permissions_image" {
  description = "Imagen por DIGEST (en tu ECR privado) con el binario chown, p. ej. busybox. Si se indica, un contenedor init no esencial hace chown de writable_paths al uid:gid de user antes de arrancar la aplicación: Fargate crea esos volúmenes como root 755 y un proceso no root no podría escribir en ellos. Solo conserva la capacidad CHOWN. null = sin contenedor init (la imagen debe declarar las rutas con VOLUME y el propietario correcto, o la aplicación no escribe en disco)."
  type        = string
  default     = null

  validation {
    condition     = var.volume_permissions_image == null || can(regex("@sha256:[0-9a-f]{64}$", var.volume_permissions_image))
    error_message = "volume_permissions_image debe referenciarse por digest: <repositorio>@sha256:<64 caracteres hexadecimales>."
  }

  validation {
    condition     = var.volume_permissions_image == null || can(regex("^[1-9][0-9]*(:[0-9]+)?$", var.user))
    error_message = "volume_permissions_image requiere un user numérico (uid[:gid]): el contenedor init no conoce los nombres de usuario de la imagen de la aplicación."
  }
}

variable "tags" {
  description = "Etiquetas adicionales."
  type        = map(string)
  default     = {}
  nullable    = false
}
