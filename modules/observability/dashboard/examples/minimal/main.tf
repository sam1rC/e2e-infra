provider "aws" {
  region = "us-east-1"
}

# Un servicio ECS; el dashboard solo contiene lo que se declara.
module "dashboard" {
  source = "../.."

  project     = "acme"
  environment = "dev"

  ecs_services = {
    web = { cluster_name = "acme-dev", service_name = "acme-dev-web" }
  }
}

output "dashboard_name" {
  description = "Nombre del dashboard."
  value       = module.dashboard.dashboard_name
}
