provider "aws" {
  region = "us-east-1"
}

variable "name_suffix" {
  description = "Sufijo para nombres de la prueba (evita colisiones en ejecuciones paralelas)."
  type        = string
  default     = "example"
  nullable    = false
}

variable "image" {
  description = "Imagen por digest (repo@sha256:...). En sandbox, la imagen nginx re-etiquetada en el ECR privado."
  type        = string
  default     = "123456789012.dkr.ecr.us-east-1.amazonaws.com/acme-dev-web@sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
  nullable    = false
}

variable "certificate_arn" {
  description = "Certificado ACM EMITIDO en la región del ALB, del dominio público de la aplicación."
  type        = string
  default     = "arn:aws:acm:us-east-1:123456789012:certificate/11111111-2222-3333-4444-555555555555"
  nullable    = false
}

module "vpc" {
  source = "../../../../network/vpc"

  project     = "acme-${var.name_suffix}"
  environment = "dev"
  cidr_block  = "10.71.0.0/16"
  az_names    = ["us-east-1a", "us-east-1b"]

  nat_mode               = "none"
  enable_flow_logs       = false # solo para el ejemplo
  publish_ssm_parameters = false
}

module "kms" {
  source = "../../../../foundation/kms-key"

  project     = "acme-${var.name_suffix}"
  environment = "dev"
  purpose     = "ecs"

  service_principals = ["logs.us-east-1.amazonaws.com"]
  via_services       = ["secretsmanager.us-east-1.amazonaws.com"]
}

module "cluster" {
  source = "../../../ecs-cluster"

  project     = "acme-${var.name_suffix}"
  environment = "dev"
  kms_key_arn = module.kms.key_arn
}

# Secreto de ejemplo: el valor no está en el código ni en el estado (se escribe fuera de OpenTofu).
resource "aws_secretsmanager_secret" "api_key" {
  name                    = "acme-${var.name_suffix}/api-key"
  description             = "Clave de API del ejemplo; el valor se escribe fuera de OpenTofu"
  kms_key_id              = module.kms.key_arn
  recovery_window_in_days = 7
}

module "alb" {
  source = "../../../alb-internal"

  project         = "acme-${var.name_suffix}"
  environment     = "dev"
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.subnet_ids["app"]
  certificate_arn = var.certificate_arn

  target_groups = {
    web = { port = 8080 }
  }

  listener_rules = {
    app = { priority = 10, target_group = "web", host_headers = ["app.example.com"] }
  }

  # La salida del ALB hacia las tareas (el SG de las tareas se crea en el módulo del servicio).
  egress_targets = {
    web = { security_group_id = module.service.security_group_id, port = 8080 }
  }
}

module "vpc_endpoints" {
  source = "../../../../network/vpc-endpoints"

  project         = "acme-${var.name_suffix}"
  environment     = "dev"
  vpc_id          = module.vpc.vpc_id
  vpc_cidr_block  = module.vpc.vpc_cidr_block
  subnet_ids      = module.vpc.subnet_ids["app"]
  route_table_ids = module.vpc.route_table_ids["app"]

  interface_services = ["ecr.api", "ecr.dkr", "logs", "secretsmanager", "xray"]
  gateway_services   = ["s3"]

  allowed_security_group_ids = {
    web = module.service.security_group_id
  }
}

module "service" {
  source = "../.."

  project     = "acme-${var.name_suffix}"
  environment = "dev"
  name        = "web"
  cluster_arn = module.cluster.cluster_arn
  vpc_id      = module.vpc.vpc_id
  subnet_ids  = module.vpc.subnet_ids["app"]

  image          = var.image
  container_port = 8080
  cpu            = 512
  memory         = 1024
  writable_paths = ["/tmp", "/var/cache/nginx"]

  environment_variables = {
    APP_ENV = "dev"
  }

  secrets = {
    API_KEY = aws_secretsmanager_secret.api_key.arn
  }
  secrets_kms_key_arns = [module.kms.key_arn]

  log_kms_key_arn    = module.kms.key_arn
  log_retention_days = 30

  # Entrada solo desde el ALB y salida solo a los endpoints de VPC y al gateway de S3 (capas de imagen de ECR).
  alb_security_group_id = module.alb.security_group_id
  target_group_arn      = module.alb.target_group_arns["web"]
  alb_enabled           = true # el ALB se crea en este mismo apply

  egress_rules = {
    vpc_endpoints = {
      description       = "HTTPS a los endpoints de VPC"
      port              = 443
      security_group_id = module.vpc_endpoints.security_group_id
    }
    s3 = {
      description    = "HTTPS al gateway de S3"
      port           = 443
      prefix_list_id = module.vpc_endpoints.gateway_endpoint_prefix_list_ids["s3"]
    }
  }

  min_tasks               = 1
  max_tasks               = 3
  cpu_target_percent      = 60
  requests_per_target     = 500
  alb_arn_suffix          = module.alb.alb_arn_suffix
  target_group_arn_suffix = module.alb.target_group_arn_suffixes["web"]

  # Permisos de la aplicación (vacío = ninguno): aquí, leer un único parámetro.
  task_role_policies = {
    read-config = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect   = "Allow"
        Action   = ["ssm:GetParameter"]
        Resource = ["arn:aws:ssm:us-east-1:*:parameter/acme/${var.name_suffix}/config"]
      }]
    })
  }
}

output "service_name" {
  description = "Nombre del servicio."
  value       = module.service.service_name
}

output "alb_dns_name" {
  description = "DNS interno del ALB."
  value       = module.alb.alb_dns_name
}
