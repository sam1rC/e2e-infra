provider "aws" {
  region = "us-east-1"
}

variable "name_suffix" {
  description = "Sufijo para nombres de la prueba (evita colisiones en ejecuciones paralelas)."
  type        = string
  default     = "example"
  nullable    = false
}

variable "certificate_arn" {
  description = "Certificado ACM EMITIDO en la región del ALB, del dominio público de la aplicación."
  type        = string
  default     = "arn:aws:acm:us-east-1:123456789012:certificate/11111111-2222-3333-4444-555555555555"
  nullable    = false
}

data "aws_caller_identity" "current" {}

# Cuenta de ELB que escribe los logs en us-east-1 (las regiones abiertas desde 2022 usan el
# principal de servicio logdelivery.elasticloadbalancing.amazonaws.com).
data "aws_elb_service_account" "current" {}

module "vpc" {
  source = "../../../../network/vpc"

  project     = "acme-${var.name_suffix}"
  environment = "dev"
  cidr_block  = "10.61.0.0/16"
  az_names    = ["us-east-1a", "us-east-1b"]

  nat_mode         = "none"
  enable_flow_logs = false # solo para el ejemplo
}

# Bucket de logs del ALB: SSE-S3 (el ALB no admite SSE-KMS aquí) y política que autoriza la entrega.
module "logs" {
  source = "../../../../storage/s3-bucket"

  project       = "acme"
  environment   = "dev"
  purpose       = "logs"
  bucket_name   = "acme-dev-alb-logs-${data.aws_caller_identity.current.account_id}-${var.name_suffix}"
  sse_algorithm = "AES256"
  force_destroy = true # solo porque es un ejemplo efímero

  lifecycle_config = {
    expiration_days = 90
  }

  policy_statements = [
    {
      sid            = "AllowAlbLogDelivery"
      actions        = ["s3:PutObject"]
      resource_paths = ["/alb/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]
      principals = [
        { type = "AWS", identifiers = [data.aws_elb_service_account.current.arn] },
      ]
    },
  ]
}

# Security group de los targets (en producción lo crea el módulo ecs-service).
resource "aws_security_group" "targets" {
  name_prefix = "acme-${var.name_suffix}-targets-"
  description = "Targets del ejemplo: entrada solo desde el ALB"
  vpc_id      = module.vpc.vpc_id

  lifecycle {
    create_before_destroy = true
  }
}

module "alb" {
  source = "../.."

  project         = "acme-${var.name_suffix}"
  environment     = "dev"
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.subnet_ids["app"]
  certificate_arn = var.certificate_arn

  idle_timeout_seconds    = 55
  access_logs_bucket_name = module.logs.bucket_id

  target_groups = {
    web = {
      port = 8080
      health_check = {
        path    = "/healthz"
        matcher = "200"
      }
    }
    api = {
      port             = 8081
      protocol_version = "HTTP2"
    }
  }

  listener_rules = {
    api = {
      priority      = 10
      target_group  = "api"
      host_headers  = ["app.example.com"]
      path_patterns = ["/api/*"]
    }
    web = {
      priority     = 20
      target_group = "web"
      host_headers = ["app.example.com"]
    }
  }

  egress_targets = {
    web = { security_group_id = aws_security_group.targets.id, port = 8080 }
    api = { security_group_id = aws_security_group.targets.id, port = 8081 }
  }

  depends_on = [module.logs]
}

resource "aws_vpc_security_group_ingress_rule" "targets_from_alb" {
  for_each = toset(["8080", "8081"])

  security_group_id            = aws_security_group.targets.id
  referenced_security_group_id = module.alb.security_group_id
  ip_protocol                  = "tcp"
  from_port                    = tonumber(each.value)
  to_port                      = tonumber(each.value)
  description                  = "Desde el ALB al puerto ${each.value}"
}

output "alb_dns_name" {
  description = "DNS interno del ALB."
  value       = module.alb.alb_dns_name
}

output "target_group_arns" {
  description = "ARN de los target groups."
  value       = module.alb.target_group_arns
}
