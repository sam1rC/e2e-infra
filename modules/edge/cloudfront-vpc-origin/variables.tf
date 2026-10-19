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

variable "vpc_id" {
  description = "ID de la VPC del ALB interno (para localizar el security group gestionado de los VPC origins)."
  type        = string

  validation {
    condition     = can(regex("^vpc-[0-9a-f]+$", var.vpc_id))
    error_message = "vpc_id debe tener el formato vpc-xxxxxxxx."
  }

  nullable = false
}

variable "alb_arn" {
  description = "ARN del ALB interno que actúa de origen."
  type        = string

  validation {
    condition     = can(regex("^arn:[a-z-]+:elasticloadbalancing:[a-z0-9-]+:[0-9]{12}:loadbalancer/app/", var.alb_arn))
    error_message = "alb_arn debe ser el ARN de un Application Load Balancer."
  }

  nullable = false
}

variable "alb_dns_name" {
  description = "Nombre DNS del ALB interno (dominio del origen). Con https-only CloudFront valida el certificado contra el Host reenviado, no contra este nombre (ADR 0007)."
  type        = string
  nullable    = false
}

variable "alb_security_group_id" {
  description = "Security group del ALB al que se añade la regla de entrada desde CloudFront."
  type        = string

  validation {
    condition     = can(regex("^sg-[0-9a-f]+$", var.alb_security_group_id))
    error_message = "alb_security_group_id debe tener el formato sg-xxxxxxxx."
  }

  nullable = false
}

variable "alb_ingress_source" {
  description = "Origen de la regla de entrada del ALB: cloudfront_managed_sg (SG CloudFront-VPCOrigins-Service-SG gestionado por AWS, más restrictivo), cloudfront_prefix_list (lista de prefijos origin-facing de CloudFront, respaldo) o none (la regla la crea quien llama: el módulo usa el provider de us-east-1 y el ALB está en otra región)."
  type        = string
  default     = "cloudfront_managed_sg"

  validation {
    condition     = contains(["cloudfront_managed_sg", "cloudfront_prefix_list", "none"], var.alb_ingress_source)
    error_message = "alb_ingress_source debe ser cloudfront_managed_sg, cloudfront_prefix_list o none."
  }

  nullable = false
}

variable "domain_names" {
  description = "Nombres de dominio públicos (alias) de la distribución. El certificado debe cubrirlos."
  type        = list(string)

  validation {
    condition     = length(var.domain_names) >= 1 && alltrue([for d in var.domain_names : can(regex("^([a-z0-9]([a-z0-9-]*[a-z0-9])?\\.)+[a-z]{2,}$", d))])
    error_message = "Indica al menos un dominio DNS válido en minúsculas."
  }

  nullable = false
}

variable "acm_certificate_arn" {
  description = "Certificado ACM del viewer (debe estar en us-east-1 y emitido)."
  type        = string

  validation {
    condition     = can(regex("^arn:[a-z-]+:acm:us-east-1:[0-9]{12}:certificate/", var.acm_certificate_arn))
    error_message = "acm_certificate_arn debe ser un certificado de ACM en us-east-1."
  }

  nullable = false
}

variable "web_acl_arn" {
  description = "ARN del Web ACL de WAF (scope CLOUDFRONT). null con un plan flat-rate que lo incluye."
  type        = string
  default     = null

  validation {
    condition     = var.web_acl_arn == null || can(regex("^arn:[a-z-]+:wafv2:us-east-1:[0-9]{12}:global/webacl/", var.web_acl_arn))
    error_message = "web_acl_arn debe ser un Web ACL global (CLOUDFRONT) de us-east-1."
  }
}

variable "response_headers_policy_id" {
  description = "ID de la response headers policy de seguridad (módulo security-headers)."
  type        = string
  nullable    = false
}

variable "static_path_patterns" {
  description = "Patrones de ruta servidos con caché (CachingOptimized y compresión). El orden es el de precedencia."
  type        = list(string)
  default     = ["/static/*", "/assets/*"]
  nullable    = false
}

variable "price_class" {
  description = "Clase de precio de la distribución."
  type        = string
  default     = "PriceClass_100"

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.price_class)
    error_message = "price_class debe ser PriceClass_100, PriceClass_200 o PriceClass_All."
  }

  nullable = false
}

variable "origin_read_timeout_seconds" {
  description = "Segundos que CloudFront espera la respuesta del ALB (hasta 60 sin subir la cuota)."
  type        = number
  default     = 30

  validation {
    condition     = var.origin_read_timeout_seconds >= 1 && var.origin_read_timeout_seconds <= 60
    error_message = "origin_read_timeout_seconds debe estar entre 1 y 60."
  }

  nullable = false
}

variable "zone_id" {
  description = "Zona de Route 53 donde crear los registros A/AAAA (alias) hacia la distribución. null = el DNS se gestiona fuera."
  type        = string
  default     = null
}

variable "log_bucket_arn" {
  description = "Bucket S3 para los logs de acceso (logging estándar v2, sin ACL). La entrega escribe en AWSLogs/<cuenta>/CloudFront/<log_prefix>/...: su política debe permitir s3:PutObject en AWSLogs/<cuenta>/CloudFront/* a delivery.logs.amazonaws.com con aws:SourceAccount y aws:SourceArn del delivery source <project>-<environment>-cloudfront (si falta, CloudWatch Logs añade su propia declaración y el siguiente apply la borraría). null = sin logs."
  type        = string
  default     = null
}

variable "access_logs_enabled" {
  description = "Activa los logs de acceso. Indícalo (true) cuando log_bucket_arn se crea en el mismo apply: OpenTofu necesita conocer al planificar si se crean los recursos de logging. null = activado si log_bucket_arn no es null."
  type        = bool
  default     = null

  validation {
    condition     = var.access_logs_enabled != true || var.log_bucket_arn != null
    error_message = "access_logs_enabled = true requiere log_bucket_arn."
  }
}

variable "log_prefix" {
  description = "Prefijo de los logs dentro del bucket."
  type        = string
  default     = "cloudfront"
  nullable    = false
}

variable "tags" {
  description = "Etiquetas adicionales."
  type        = map(string)
  default     = {}
  nullable    = false
}
