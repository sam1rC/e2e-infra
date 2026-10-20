# Versión del catálogo vendorizado (ADR 0005). Solo la primera capa de cada entorno y cuenta la publica.
resource "aws_ssm_parameter" "catalog_version" {
  name        = "/${var.project}/${var.environment}/catalog_version"
  description = "Versión del catálogo de infraestructura vendorizada en el repositorio (CATALOG_VERSION)."
  type        = "String"
  value       = trimspace(file("${path.root}/../../../CATALOG_VERSION"))
}
